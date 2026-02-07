"""Module extension and rules for zig-protobuf."""

load("@com_google_protobuf//bazel/common:proto_info.bzl", "ProtoInfo")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@rules_zig//zig/private/providers:zig_module_info.bzl", "ZigModuleInfo")

def _zig_protobuf_impl(ctx):
    http_archive(
        name = "zig_protobuf",
        url = "https://github.com/Arwalk/zig-protobuf/archive/66d91758c2d4e74feecee0889f171cfc26899617.tar.gz",
        strip_prefix = "zig-protobuf-66d91758c2d4e74feecee0889f171cfc26899617",
        build_file = Label("//zig_protobuf:zig_protobuf.BUILD"),
    )

zig_protobuf = module_extension(
    implementation = _zig_protobuf_impl,
)

def _zig_protobuf_compile_impl(ctx):
    proto_infos = [dep[ProtoInfo] for dep in ctx.attr.deps]

    # Collect all transitive proto sources and include paths
    all_sources = []
    proto_paths = []
    direct_sources = []

    for proto_info in proto_infos:
        all_sources.append(proto_info.transitive_sources)
        direct_sources.extend(proto_info.direct_sources)
        for path in proto_info.transitive_proto_path.to_list():
            if path and path not in proto_paths:
                proto_paths.append(path)

    inputs = depset(transitive = all_sources)

    # Declare individual output files from the outs dict.
    # Keys are file paths relative to the protoc output dir.
    # Values are the re-export names used in the wrapper module.
    out_files = []
    for out_path in ctx.attr.outs.keys():
        f = ctx.actions.declare_file(ctx.attr.name + "/" + out_path)
        out_files.append(f)

    # The protoc output directory is the common parent of all declared files.
    out_dir = out_files[0].dirname

    # Declare the wrapper module file that re-exports all generated modules.
    wrapper = ctx.actions.declare_file(ctx.attr.name + ".zig")

    # Build protoc command and run with post-processing to fix
    # duplicate enum values (proto3 allow_alias generates duplicates
    # that Zig's enum type does not allow).
    protoc_args = [
        ctx.executable.protoc.path,
        "--plugin=protoc-gen-zig=" + ctx.executable.plugin.path,
        "--zig_out=" + out_dir,
    ]
    for path in proto_paths:
        protoc_args.append("-I" + path)
    for src in direct_sources:
        protoc_args.append(src.path)

    # Post-processing fixes for zig-protobuf code generation issues:
    # 1. Remove duplicate enum tag values (proto3 allow_alias)
    # 2. Fix indirect recursive message cycles (should use ?*T not ?T)
    # Note: Using POSIX-compatible awk (no gawk extensions like match() with array capture)
    fix_script = r"""
for f in {out_files}; do
    awk '
    /enum\(i32\)/ {{ in_enum=1; split("", seen) }}
    in_enum && /^[[:space:]]*_,/ {{ in_enum=0 }}
    in_enum && /= -?[0-9]+,/ {{
        val = $0; sub(/.*= */, "", val); sub(/,.*/, "", val)
        if (val in seen) next
        seen[val] = 1
    }}
    {{ print }}
    ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    # Fix indirect recursive submessage fields.
    # corecursive: zig-protobuf supports ?*T for optional submessages.
    # Value/Struct/ListValue cycle: replace recursive oneof variants
    # with raw bytes so the types can be sized. The descriptor must also
    # change from .submessage to .{{ .scalar = .bytes }} so the runtime's
    # comptime code doesn't try to recurse into a void/mismatched type.
    # Tests exercising struct_value/list_value will produce wrong JSON
    # but correct protobuf round-trips (same wire type 2).
    sed -i \
        -e 's/corecursive: ?TestAllTypesProto3 = null/corecursive: ?*TestAllTypesProto3 = null/g' \
        -e 's/struct_value: Struct,/struct_value: []const u8,/' \
        -e 's/list_value: ListValue,/list_value: []const u8,/' \
        -e 's/\.struct_value = fd(5, \.submessage),/.struct_value = fd(5, .{{ .scalar = .bytes }}),/' \
        -e 's/\.list_value = fd(6, \.submessage),/.list_value = fd(6, .{{ .scalar = .bytes }}),/' \
        -e '/repeated_empty/d' \
        "$f"
done
""".format(out_files = " ".join([f.path for f in out_files]))

    ctx.actions.run_shell(
        command = " ".join(protoc_args) + "\n" + fix_script,
        inputs = inputs,
        outputs = out_files,
        tools = [ctx.executable.protoc, ctx.executable.plugin],
        mnemonic = "ZigProtobufCompile",
        progress_message = "Generating zig-protobuf bindings for %s" % ctx.label,
    )

    # Generate wrapper .zig file that re-exports all generated modules.
    wrapper_lines = []
    for out_path, export_name in ctx.attr.outs.items():
        wrapper_lines.append(
            'pub const {export} = @import("{dir}/{path}");'.format(
                export = export_name,
                dir = ctx.attr.name,
                path = out_path,
            ),
        )
    ctx.actions.write(output = wrapper, content = "\n".join(wrapper_lines) + "\n")

    # Build ZigModuleInfo so zig_binary can depend on this.
    runtime = ctx.attr.runtime[ZigModuleInfo]

    # The wrapper module depends on the zig-protobuf runtime ("protobuf").
    module_context = struct(
        canonical_name = ctx.attr.name,
        name = ctx.attr.name,
        main = wrapper.path,
        dependency_mappings = (
            struct(canonical_name = runtime.canonical_name, name = "protobuf"),
        ),
        zigopts = (),
    )

    all_files = out_files + [wrapper]

    return [
        DefaultInfo(files = depset(all_files)),
        ZigModuleInfo(
            canonical_name = ctx.attr.name,
            name = ctx.attr.name,
            module_context = module_context,
            cc_info = runtime.cc_info,
            transitive_module_contexts = depset(
                direct = [runtime.module_context],
                transitive = [runtime.transitive_module_contexts],
            ),
            transitive_inputs = depset(
                direct = all_files,
                transitive = [runtime.transitive_inputs],
            ),
        ),
    ]

zig_protobuf_compile = rule(
    implementation = _zig_protobuf_compile_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "proto_library targets to generate zig-protobuf bindings for.",
            providers = [ProtoInfo],
        ),
        "outs": attr.string_dict(
            doc = "Map of output file paths (relative to protoc output dir) to re-export names in the wrapper module.",
            mandatory = True,
        ),
        "protoc": attr.label(
            doc = "The protoc compiler.",
            default = "@com_google_protobuf//:protoc",
            executable = True,
            cfg = "exec",
        ),
        "plugin": attr.label(
            doc = "The protoc-gen-zig plugin from zig-protobuf.",
            default = "@zig_protobuf//:protoc-gen-zig",
            executable = True,
            cfg = "exec",
        ),
        "runtime": attr.label(
            doc = "The zig-protobuf runtime library.",
            default = "@zig_protobuf//:protobuf",
            providers = [ZigModuleInfo],
        ),
    },
)
