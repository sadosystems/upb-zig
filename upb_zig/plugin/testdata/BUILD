load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_zig//zig:defs.bzl", "zig_library", "zig_binary", "zig_test")
load("//upb_zig:defs.bzl", "zig_proto_library")

proto_library(
    name = "simple_proto",
    srcs = ["simple.proto"],
)

zig_proto_library(
    name = "simple_zig_proto",
    deps = [":simple_proto"],
)

zig_library(
    name = "simple_pb",
    main = ":simple_zig_proto",
    srcs = [":simple_zig_proto"],
    deps = ["//upb_zig/runtime:upb_zig"],
)


# Test that the generated code compiles with the runtime
# Uses the generated file directly with runtime dependencies
zig_test(
    name = "simple_proto_test",
    main = "simple_proto_test.zig",
    deps = [":simple_pb"],
    zigopts = ["-lc"],
)
