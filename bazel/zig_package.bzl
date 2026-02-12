"""Rule for packaging a zig_library as a distributable Zig package directory."""

load("@rules_zig//zig/private/providers:zig_module_info.bzl", "ZigModuleInfo")

# Provider to carry C source files collected by the aspect.
CcSourcesInfo = provider(
    fields = {"sources": "depset of File, all C/C++ source files from the transitive dep graph."},
)

def _cc_sources_aspect_impl(target, ctx):
    sources = []

    # Collect srcs and hdrs from cc_library (and similar) rules.
    if hasattr(ctx.rule.attr, "srcs"):
        for src in ctx.rule.attr.srcs:
            sources.append(src.files)
    if hasattr(ctx.rule.attr, "hdrs"):
        for hdr in ctx.rule.attr.hdrs:
            sources.append(hdr.files)

    # Accumulate transitively from deps.
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if CcSourcesInfo in dep:
                sources.append(dep[CcSourcesInfo].sources)

    return [CcSourcesInfo(sources = depset(transitive = sources))]

cc_sources_aspect = aspect(
    implementation = _cc_sources_aspect_impl,
    attr_aspects = ["deps"],
)

def _zig_package_impl(ctx):
    module = ctx.attr.lib[ZigModuleInfo]

    # Collect all source files.
    src_depsets = []
    src_depsets.append(module.transitive_inputs)
    if CcSourcesInfo in ctx.attr.lib:
        src_depsets.append(ctx.attr.lib[CcSourcesInfo].sources)
    all_srcs = depset(transitive = src_depsets).to_list()

    # Output is a directory with build.zig at the root.
    out_dir = ctx.actions.declare_directory(ctx.label.name)

    # Build copy commands: build.zig/zon go at root, everything else keeps its path.
    cmds = ['mkdir -p "$1"']
    inputs = list(ctx.files.build_zig) + list(ctx.files.build_zig_zon) + all_srcs

    cmds.append('cp %s "$1/build.zig"' % ctx.file.build_zig.path)
    cmds.append('cp %s "$1/build.zig.zon"' % ctx.file.build_zig_zon.path)

    dirs = {}
    for f in all_srcs:
        # short_path for external files starts with ../repo_name/...
        # Remap to external/repo_name/... for a cleaner layout.
        path = f.short_path
        if path.startswith("../"):
            path = "external/" + path[3:]
        parent = path.rsplit("/", 1)[0] if "/" in path else ""
        if parent and parent not in dirs:
            dirs[parent] = True
            cmds.append('mkdir -p "$1/%s"' % parent)
        cmds.append('cp -L %s "$1/%s"' % (f.path, path))

    ctx.actions.run_shell(
        outputs = [out_dir],
        inputs = inputs,
        command = " && ".join(cmds),
        arguments = [out_dir.path],
    )

    return [DefaultInfo(files = depset([out_dir]))]

zig_package = rule(
    implementation = _zig_package_impl,
    attrs = {
        "lib": attr.label(
            mandatory = True,
            providers = [ZigModuleInfo],
            aspects = [cc_sources_aspect],
            doc = "The zig_library target to package.",
        ),
        "build_zig": attr.label(
            mandatory = True,
            allow_single_file = [".zig"],
            doc = "The build.zig file, placed at the package root.",
        ),
        "build_zig_zon": attr.label(
            mandatory = True,
            allow_single_file = [".zon"],
            doc = "The build.zig.zon file, placed at the package root.",
        ),
    },
)
