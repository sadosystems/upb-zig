load("@rules_python//python:defs.bzl", "py_binary", "py_library")
load("@rules_python//python:packaging.bzl", "py_wheel")

package(default_visibility = ["//visibility:public"])

py_library(
    name = "codegen",
    srcs = ["codegen.py"],
    deps = [
        "@pypi//mako",
    ],
)

py_library(
    name = "protoc-gen-zig-lib",
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

py_wheel(
    name = "protoc-gen-zig-wheel",
    distribution = "protoc_gen_zig",
    python_tag = "py3",
    version = "0.0.1",
    deps = [":protoc-gen-zig-lib"],
    entry_points = {
        "console_scripts": {
            "protoc_gen_zig": "protoc_gen_zig:main",
        },
    },
)