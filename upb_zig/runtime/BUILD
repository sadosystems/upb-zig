load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_zig//zig:defs.bzl", "zig_library", "zig_test")
load("//bazel:zig_package.bzl", "zig_package")


genrule(
    name = "runtime_tarball",
    srcs = [
        ":runtime_package",
    ],
    outs = ["upb-zig-runtime.tar.gz"],
    cmd = "tar -chzf $@ --transform 's,^,upb-zig-runtime/,' -C $(SRCS) .",
)
  
zig_package(
    name = "runtime_package",
    lib = ":upb_zig",
    build_zig = "build.zig",
    build_zig_zon = "build.zig.zon",
    extra_srcs = [
        "@com_google_protobuf//upb/reflection:descriptor_upb_proto_cmake",
    ],
)

package(default_visibility = ["//visibility:public"])

# C helper library - wraps upb inline functions to avoid Zig alignment issues
cc_library(
    name = "upb_helpers",
    srcs = ["upb_helpers.c"],
    hdrs = ["upb_helpers.h"],
    deps = [
        "@com_google_protobuf//upb/mem",
        "@com_google_protobuf//upb/message",
        "@com_google_protobuf//upb/base",
        "@com_google_protobuf//upb/reflection:reflection",
        "@com_google_protobuf//upb/mini_table",
        "@com_google_protobuf//upb/json:json",
    ],
)

# Main upb_zig runtime library - Zig wrapper over upb
# Note: reflection API is only used through C helpers, not directly from Zig
zig_library(
    name = "upb_zig",
    main = "upb_zig.zig",
    deps = [
        ":upb_helpers",
        "@com_google_protobuf//upb/mem",
        "@com_google_protobuf//upb/message",
        "@com_google_protobuf//upb/wire",
        "@com_google_protobuf//upb/base",
        "@com_google_protobuf//upb/mini_table",
    ],
    zigopts = [
        "-lc",
        "-Iexternal/protobuf+",
        "-Iupb_zig/runtime",  # For upb_helpers.h
    ],
)

# Test that verifies upb integration works
zig_test(
    name = "upb_zig_test",
    main = "upb_zig.zig",
    deps = [
        ":upb_helpers",
        "@com_google_protobuf//upb/mem",
        "@com_google_protobuf//upb/message",
        "@com_google_protobuf//upb/wire",
        "@com_google_protobuf//upb/base",
    ],
    zigopts = [
        "-lc",
        "-Iexternal/protobuf+",
        "-Iupb_zig/runtime",
    ],
)
