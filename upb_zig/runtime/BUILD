load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_zig//zig:defs.bzl", "zig_library", "zig_test")
load("//bazel:zig_package.bzl", "zig_package")
load("//upb_zig:defs.bzl", "zig_proto_library")

package(default_visibility = ["//visibility:public"])

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
    lib = ":upb_runtime",
    build_zig = "build.zig",
    build_zig_zon = "build.zig.zon",
    extra_srcs = [
        "@com_google_protobuf//upb/reflection:descriptor_upb_proto_cmake",
        "@com_google_protobuf//upb/mem",
        "@com_google_protobuf//upb/message",
        "@com_google_protobuf//upb/base",
        "@com_google_protobuf//upb/reflection:reflection",
        "@com_google_protobuf//upb/mini_table",
        "@com_google_protobuf//upb/json:json",
    ],
)

zig_library(
    name = "upb_runtime",
    main = "re_export_everything.zig",
    deps = [
        ":wkt",
        ":upb_zig",
    ],
    zigopts = [
        "-lc",
        "-Iexternal/protobuf+",
        "-Iupb_zig/runtime",  # For upb_helpers.h
    ],
)

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


# ----- Well Known Types Re-Export -----

zig_proto_library(
    name = "any_pb", 
    deps = ["@com_google_protobuf//:any_proto"]
)

zig_proto_library(
    name = "api_pb", 
    deps = ["@com_google_protobuf//:api_proto"]
)

zig_proto_library(
    name = "duration_pb", 
    deps = ["@com_google_protobuf//:duration_proto"]
)

zig_proto_library(
    name = "empty_pb", 
    deps = ["@com_google_protobuf//:empty_proto"]
)

zig_proto_library(
    name = "field_mask_pb", 
    deps = ["@com_google_protobuf//:field_mask_proto"]
)

zig_proto_library(
    name = "source_context_pb", 
    deps = ["@com_google_protobuf//:source_context_proto"]
)

zig_proto_library(
    name = "struct_pb", 
    deps = ["@com_google_protobuf//:struct_proto"]
)

zig_proto_library(
    name = "timestamp_pb", 
    deps = ["@com_google_protobuf//:timestamp_proto"]
)

zig_proto_library(
    name = "type_pb", 
    deps = ["@com_google_protobuf//:type_proto"]
)

zig_proto_library(
    name = "wrappers_pb", 
    deps = ["@com_google_protobuf//:wrappers_proto"]
)


zig_library(
    name = "wkt",
    main = "re_export_well_known_types.zig",
    deps = [
        ":upb_zig",
        ":any_pb",
        ":api_pb",
        ":duration_pb",
        ":empty_pb",
        ":field_mask_pb",
        ":source_context_pb",
        ":struct_pb",
        ":timestamp_pb",
        ":type_pb",
        ":wrappers_pb",
    ],
    zigopts = ["-lc"],
)

