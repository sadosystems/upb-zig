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

make_shell_script(
    name = "gen_test_conformance_zig_protobuf",
    out = "test_conformance_zig_protobuf.sh",
    contents = "$1 --failure_list $2 $3",
)

sh_test(
    name = "conformance",
    srcs = ["test_conformance_zig_protobuf.sh"],
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location :expected_failures.txt)",
        "$(location :protobuf_zig_testee)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        ":expected_failures.txt",
        ":protobuf_zig_testee",
    ],
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    tags = ["should_fail"],
)


