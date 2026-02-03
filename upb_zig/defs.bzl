"""Bazel rules for generating Zig protobuf bindings via upb_zig."""

load("@com_google_protobuf//bazel/common:proto_common.bzl", "proto_common")
load("@com_google_protobuf//bazel/common:proto_info.bzl", "ProtoInfo")
load("@com_google_protobuf//bazel/private:toolchain_helpers.bzl", "toolchains")
load("@rules_zig//zig/private/providers:zig_module_info.bzl", "ZigModuleInfo")

_ZIG_PROTO_TOOLCHAIN = Label("//upb_zig:zig_proto_toolchain_type")

_ZigProtoInfo = provider(
    doc = "Encapsulates information needed by the Zig proto rules.",
    fields = {
        "direct_sources": "(list[File]) The directly generated Zig sources.",
        "transitive_sources": "(depset[File]) All transitive Zig sources.",
        "direct_modules": "(dict[str, File]) Module name -> source file for direct sources.",
        "transitive_modules": "(dict[str, File]) Module name -> source file for all transitive sources.",
    },
)

def _proto_file_to_module_name(proto_source):
    """Convert a proto source file path to its Zig module name.

    Example: "google/protobuf/any.proto" -> "google_protobuf_any"
    Example: "external/protobuf+/editions/golden/test.proto" -> "editions_golden_test"
    """
    name = proto_source.basename
    if name.endswith(".proto"):
        name = name[:-6]

    path = proto_source.path
    if path.endswith(".proto"):
        path = path[:-6]

    parts = path.split("/")

    # Skip external repo prefix (e.g., "external/protobuf+/")
    for i, part in enumerate(parts):
        if part == "external" and i + 1 < len(parts):
            parts = parts[i + 2:]  # Skip "external" and repo name
            break

    # Skip _virtual_imports directories
    for i, part in enumerate(parts):
        if part == "_virtual_imports" and i + 2 < len(parts):
            parts = parts[i + 2:]
            break

    return "_".join(parts).replace(".", "_").replace("-", "_")

def _filter_provider(provider, *attrs):
    return [dep[provider] for attr in attrs for dep in attr if provider in dep]

def _zig_proto_aspect_impl(target, ctx):
    """Generates and compiles Zig code for a proto_library."""
    _proto_library = ctx.rule.attr

    if proto_common.INCOMPATIBLE_ENABLE_PROTO_TOOLCHAIN_RESOLUTION:
        toolchain = ctx.toolchains[_ZIG_PROTO_TOOLCHAIN]
        if not toolchain:
            fail("No toolchains registered for '%s'." % _ZIG_PROTO_TOOLCHAIN)
        proto_lang_toolchain_info = toolchain.proto
    else:
        proto_lang_toolchain_info = ctx.attr._aspect_proto_toolchain[proto_common.ProtoLangToolchainInfo]

    proto_info = target[ProtoInfo]
    generated_sources = []

    if proto_info.direct_sources:
        generated_sources = proto_common.declare_generated_files(
            actions = ctx.actions,
            proto_info = proto_info,
            extension = ".pb.zig",
        )

        proto_root = proto_info.proto_source_root
        if proto_root.startswith(ctx.bin_dir.path):
            proto_root = proto_root[len(ctx.bin_dir.path) + 1:]

        plugin_output = ctx.bin_dir.path + "/" + proto_root

        proto_common.compile(
            actions = ctx.actions,
            proto_info = proto_info,
            proto_lang_toolchain_info = proto_lang_toolchain_info,
            generated_files = generated_sources,
            plugin_output = plugin_output,
        )

    deps = _filter_provider(_ZigProtoInfo, getattr(_proto_library, "deps", []))
    transitive_sources = depset(
        direct = generated_sources,
        transitive = [dep.transitive_sources for dep in deps],
    )

    direct_modules = {}
    for i, proto_src in enumerate(proto_info.direct_sources):
        if i < len(generated_sources):
            module_name = _proto_file_to_module_name(proto_src)
            direct_modules[module_name] = generated_sources[i]

    transitive_modules = dict(direct_modules)
    for dep in deps:
        transitive_modules.update(dep.transitive_modules)

    return [
        _ZigProtoInfo(
            direct_sources = generated_sources,
            transitive_sources = transitive_sources,
            direct_modules = direct_modules,
            transitive_modules = transitive_modules,
        ),
    ]

_zig_proto_aspect = aspect(
    implementation = _zig_proto_aspect_impl,
    attrs = toolchains.if_legacy_toolchain({
        "_aspect_proto_toolchain": attr.label(
            default = "//upb_zig:zig_toolchain",
        ),
    }),
    attr_aspects = ["deps"],
    required_providers = [ProtoInfo],
    provides = [_ZigProtoInfo],
    toolchains = toolchains.use_toolchain(_ZIG_PROTO_TOOLCHAIN),
)

def _zig_proto_library_impl(ctx):
    """Generates Zig proto bindings and returns a ZigModuleInfo provider."""
    if not ctx.attr.deps:
        fail("'deps' attribute mustn't be empty.")

    zigproto_infos = _filter_provider(_ZigProtoInfo, ctx.attr.deps)

    direct_outputs = []
    direct_modules = {}
    transitive_modules = {}
    for info in zigproto_infos:
        direct_outputs.extend(info.direct_sources)
        direct_modules.update(info.direct_modules)
        transitive_modules.update(info.transitive_modules)

    if not direct_outputs:
        fail("No sources generated for zig_proto_library")

    main_file = direct_outputs[0]
    all_files = list(transitive_modules.values())

    # Get the main module name (first direct module)
    main_module_name = list(direct_modules.keys())[0] if direct_modules else ctx.label.name

    # Build module contexts for each transitive module EXCEPT the main one
    transitive_module_contexts = []
    for mod_name, mod_file in transitive_modules.items():
        if mod_name == main_module_name:
            continue  # Skip - this is the main module
        transitive_module_contexts.append(struct(
            canonical_name = mod_name,
            name = mod_name,
            main = mod_file.path,
            dependency_mappings = (
                # Each transitive module also needs upb_zig!
                struct(canonical_name = "upb_zig", name = "upb_zig"),
            ),
            zigopts = (),
        ))


    # Build dependency mappings for the main module
    dependency_mappings = []
    for mod_name in transitive_modules.keys():
        if mod_name != main_module_name:
            dependency_mappings.append(struct(
                canonical_name = mod_name,
                name = mod_name,
            ))

    dependency_mappings.append(struct(
        canonical_name = "upb_zig",
        name = "upb_zig",
    ))

    main_module_context = struct(
        canonical_name = main_module_name,
        name = main_module_name,
        main = main_file.path,
        dependency_mappings = tuple(dependency_mappings),
        zigopts = (),
    )

    # Get ZigModuleInfo from runtime
    runtime_zig_info = ctx.attr._runtime[ZigModuleInfo]

    # Merge runtime's transitive contexts
    all_transitive_contexts = transitive_module_contexts + [runtime_zig_info.module_context] + runtime_zig_info.transitive_module_contexts.to_list()
    all_transitive_inputs = all_files + runtime_zig_info.transitive_inputs.to_list()

    return [
        DefaultInfo(
            files = depset(all_files),
        ),
        ZigModuleInfo(
            canonical_name = main_module_name,
            name = main_module_name,
            module_context = main_module_context,
            transitive_inputs = depset(all_transitive_inputs),
            transitive_module_contexts = depset(all_transitive_contexts),
            cc_info = runtime_zig_info.cc_info,
        ),
        _ZigProtoInfo(
            direct_sources = direct_outputs,
            transitive_sources = depset(all_files),
            direct_modules = direct_modules,
            transitive_modules = transitive_modules,
        ),
    ]

# Export the provider so it can be used by other rules
ZigProtoInfo = _ZigProtoInfo

zig_proto_library = rule(
    implementation = _zig_proto_library_impl,
    doc = """
Use `zig_proto_library` to generate Zig libraries from `.proto` files.

The convention is to name the `zig_proto_library` rule `foo_zig_proto`,
when wrapping `proto_library` rule `foo_proto`.

`deps` must point to `proto_library` rules.

Example:
```starlark
load("@rules_proto//proto:defs.bzl", "proto_library")
load("//upb_zig:defs.bzl", "zig_proto_library")

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
)

zig_proto_library(
    name = "foo_zig_proto",
    deps = [":foo_proto"],
)

# Use directly - no zig_library wrapper needed!
zig_binary(
    name = "app",
    main = "main.zig",
    deps = [":foo_zig_proto"],
)
```
""",
    attrs = {
        "deps": attr.label_list(
            doc = "The list of proto_library rules to generate Zig libraries for.",
            providers = [ProtoInfo],
            aspects = [_zig_proto_aspect],
        ),
        "_runtime": attr.label(
            default = "//upb_zig/runtime:upb_zig",
            providers = [ZigModuleInfo],  
        ),
    },
)