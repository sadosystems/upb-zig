load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_zig//zig:defs.bzl", "zig_library", "zig_test")

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
