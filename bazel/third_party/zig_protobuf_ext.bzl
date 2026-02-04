"""Module extension to fetch zig-protobuf source."""

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
