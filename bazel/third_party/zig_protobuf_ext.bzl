"""Module extension to fetch zig-protobuf source."""
load("@com_google_protobuf//bazel/common:proto_info.bzl", "ProtoInfo")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _zig_protobuf_impl(ctx):
    http_archive(
        name = "zig_protobuf",
        url = "https://github.com/Arwalk/zig-protobuf/archive/refs/tags/v3.0.1.tar.gz",
        sha256 = "f7ba0c414978813805e6a9f5897fa4a4cb00e775143c96c4625ca4d91ebac77d",
        strip_prefix = "zig-protobuf-3.0.1",
        build_file = Label("//bazel/third_party:zig_protobuf.BUILD"),
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

    # Use a tree artifact (directory) for output since zig-protobuf
    # names output files by proto package name, not input filename.
    out_dir = ctx.actions.declare_directory(ctx.attr.name + "_out")

    args = ctx.actions.args()
    args.add("--plugin=protoc-gen-zig=" + ctx.executable.plugin.path)
    args.add("--zig_out=" + out_dir.path)

    for path in proto_paths:
        args.add("-I" + path)

    for src in direct_sources:
        args.add(src.path)

    ctx.actions.run(
        executable = ctx.executable.protoc,
        arguments = [args],
        inputs = inputs,
        outputs = [out_dir],
        tools = [ctx.executable.plugin],
        mnemonic = "ZigProtobufCompile",
        progress_message = "Generating zig-protobuf bindings",
    )

    return [DefaultInfo(files = depset([out_dir]))]

zig_protobuf_compile = rule(
    implementation = _zig_protobuf_compile_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "proto_library targets to generate zig-protobuf bindings for.",
            providers = [ProtoInfo],
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
    },
)
