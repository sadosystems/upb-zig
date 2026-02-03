# upb_zig: Conformant Protobuf for Zig via upb

load("@com_google_protobuf//bazel/toolchains:proto_lang_toolchain.bzl", "proto_lang_toolchain")

package(default_visibility = ["//visibility:public"])

# Toolchain type for Zig proto generation
toolchain_type(name = "zig_proto_toolchain_type")

# Proto language toolchain for Zig
proto_lang_toolchain(
    name = "zig_toolchain",
    command_line = "--zig_out=%s",
    plugin = "//upb_zig/plugin:protoc-gen-zig",
    plugin_format_flag = "--plugin=protoc-gen-zig=%s",
    progress_message = "Generating Zig proto_library %{label}",
    runtime = "//upb_zig/runtime:upb_zig",
)

# Register the toolchain
toolchain(
    name = "zig_proto_toolchain",
    toolchain = ":zig_toolchain",
    toolchain_type = ":zig_proto_toolchain_type",
)
