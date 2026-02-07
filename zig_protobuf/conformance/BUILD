load("@rules_zig//zig:defs.bzl", "zig_library", "zig_binary", "zig_test")
load("//bazel:build_defs.bzl", "make_shell_script")

exports_files(["expected_failures.txt"])

package(default_visibility = ["//visibility:public"])

# zig_protobuf Conformance testee binary - implements the conformance testing protocol
# Reads ConformanceRequest from stdin, writes ConformanceResponse to stdout
# Uses generated Zig bindings to decode/encode test messages
zig_binary(
    name = "protobuf_zig_testee",
    testonly = True,
    main = "protobuf_zig_testee.zig",
    deps = [
        "@zig_protobuf//:conformance_zig_protos",
    ],
    zigopts = ["-lc", "-freference-trace=20"],
)

genrule(
    name = "protobuf_zig_fails",
    testonly = True,
    outs = ["protobuf_zig_fails.txt"],
    tools = [":protobuf_zig_testee", "@com_google_protobuf//conformance:conformance_test_runner"],
    cmd = "$(location @com_google_protobuf//conformance:conformance_test_runner) --maximum_edition 2023 --enforce_recommended $(location :protobuf_zig_testee) > $@ 2>&1 || true",
)
