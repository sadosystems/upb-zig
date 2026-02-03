load("@rules_python//python:defs.bzl", "py_binary", "py_library")

package(default_visibility = ["//visibility:public"])

py_library(
    name = "codegen",
    srcs = ["codegen.py"],
    deps = [
        "@pypi//mako",
    ],
)

py_binary(
    name = "protoc-gen-zig",
    srcs = ["protoc_gen_zig.py"],
    main = "protoc_gen_zig.py",
    deps = [
        ":codegen",
        "@pypi//protobuf",
    ],
)
