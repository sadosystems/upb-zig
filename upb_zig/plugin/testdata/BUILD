load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_zig//zig:defs.bzl", "zig_library", "zig_binary", "zig_test")
load("//upb_zig:defs.bzl", "zig_proto_library")

proto_library(
    name = "simple_proto",
    srcs = ["simple.proto"],
    deps = [
        "@com_google_protobuf//:timestamp_proto",
    ],
)
zig_proto_library(
    name = "simple_zig_pb",
    deps = [":simple_proto"],
)

zig_proto_library(
    name = "timestamp_zig_pb",
    deps = ["@com_google_protobuf//:timestamp_proto"],
)

# Test that the generated code compiles with the runtime
# Uses the generated file directly with runtime dependencies
zig_test(
    name = "simple_proto_test",
    main = "simple_proto_test.zig",
    deps = [":simple_zig_pb", "//upb_zig/runtime:upb_zig"],
    zigopts = ["-lc"],
)
