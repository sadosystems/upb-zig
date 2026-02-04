load("@com_google_protobuf//bazel/toolchains:proto_lang_toolchain.bzl", "proto_lang_toolchain")
load("@rules_python//python:defs.bzl", "py_library")
load("@rules_python//python:packaging.bzl", "py_package", "py_wheel")

package(default_visibility = ["//visibility:public"])

# --- protoc-gen-zig Toolchain Resolution ---

toolchain_type(name = "zig_proto_toolchain_type")

proto_lang_toolchain(
    name = "zig_toolchain",
    command_line = "--zig_out=%s",
    plugin = "//upb_zig/plugin:protoc-gen-zig",
    plugin_format_flag = "--plugin=protoc-gen-zig=%s",
    progress_message = "Generating Zig proto_library %{label}",
    runtime = "//upb_zig/runtime:upb_zig",
)

toolchain(
    name = "zig_proto_toolchain",
    toolchain = ":zig_toolchain",
    toolchain_type = ":zig_proto_toolchain_type",
)

# ----------- protoc-gen-zig Wheel ----------

py_library(
    name = "pkg_lib",
    srcs = ["__init__.py"],
    deps = ["//upb_zig/plugin:protoc_gen_zig_lib"],
)

py_package(
    name = "protoc_gen_zig_pkg",
    packages = ["upb_zig"],
    deps = [":pkg_lib",],
)

py_wheel(
    name = "plugin_wheel",
    distribution = "protoc_gen_zig",
    version = "0.0.1",
    python_tag = "py3",
    summary = "A protoc plugin that generates Zig bindings over upb",
    description_file = "//upb_zig/plugin:PYPI_DESCRIPTION.md",
    homepage = "https://github.com/sadosystems/upb-zig",
    author = "William Murray",
    author_email = "william.matthew.murray@gmail.com",
    license = "",
    classifiers = [
        "Programming Language :: Python :: 3",
    ],
    project_urls = {
        "Source": "https://github.com/sadosystems/upb-zig",
        "Bug Tracker": "https://github.com/sadosystems/upb-zig/issues",
    },
    python_requires = ">=3.10",
    requires = ["protobuf", "mako"],
    deps = [":protoc_gen_zig_pkg"],
    entry_points = {
        "console_scripts": ["protoc-gen-zig = upb_zig.plugin.protoc_gen_zig:main"],
    },
)