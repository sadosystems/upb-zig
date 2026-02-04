load("@rules_python//python:defs.bzl", "py_binary", "py_library")
load("@rules_python//python:packaging.bzl", "py_package", "py_wheel")

package(default_visibility = ["//visibility:public"])

py_library(
    name = "codegen",
    srcs = ["codegen.py", "__init__.py"],
    deps = [
        "@pypi//mako",
    ],
)

py_library(
    name = "protoc_gen_zig_lib",
    srcs = ["protoc_gen_zig.py"],
    deps = [
        ":codegen",
        "@pypi//protobuf",
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

exports_files(["DESCRIPTION.md"])
