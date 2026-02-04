load("@rules_zig//zig:defs.bzl", "zig_library", "zig_binary")
load("@//bazel/third_party:zig_protobuf_ext.bzl", "zig_protobuf_compile")

package(default_visibility = ["//visibility:public"])

# zig-protobuf runtime library
zig_library(
    name = "protobuf",
    main = "src/protobuf.zig",
    srcs = [
        "src/wire.zig",
        "src/json.zig",
    ],
)

# zig-protobuf protoc-gen-zig plugin
zig_binary(
    name = "protoc-gen-zig",
    main = "bootstrapped-generator/main.zig",
    srcs = [
        "bootstrapped-generator/FullName.zig",
        "bootstrapped-generator/google/protobuf.pb.zig",
        "bootstrapped-generator/google/protobuf/compiler.pb.zig",
    ],
    deps = [":protobuf"],
)


# Generate conformance proto bindings using zig-protobuf's protoc-gen-zig.
zig_protobuf_compile(
    name = "conformance_zig_protos",
    deps = [
        "@com_google_protobuf//conformance:conformance_proto",
        "@com_google_protobuf//conformance/test_protos:test_messages_proto3_proto",
    ],
)
