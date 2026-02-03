# # Conformance test harness for upb_zig
load("@rules_zig//zig:defs.bzl", "zig_library", "zig_binary", "zig_test")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("//upb_zig:defs.bzl", "zig_proto_library")
load("//bazel:build_defs.bzl", "make_shell_script")

zig_proto_library(
    name = "conformance_pb",
    deps = ["@com_google_protobuf//conformance:conformance_proto"],
)

zig_proto_library(
    name = "zig_test_messages_proto3",
    deps = ["@com_google_protobuf//conformance/test_protos:test_messages_proto3_proto"],
)

zig_proto_library(
    name = "zig_test_messages_proto2",
    deps = ["@com_google_protobuf//conformance/test_protos:test_messages_proto2_proto"],
)

zig_proto_library(
    name = "zig_test_messages_proto3_editions",
    testonly = True,
    deps = ["@com_google_protobuf//conformance/test_protos:test_messages_proto3_editions_proto"],
)

zig_proto_library(
    name = "zig_test_messages_proto2_editions",
    testonly = True,
    deps = ["@com_google_protobuf//conformance/test_protos:test_messages_proto2_editions_proto"],
)

# Test that the generated code compiles with the runtime
# Uses the generated file directly with runtime dependencies
zig_test(
    name = "basic_conformance",
    main = "basic_conformance.zig",
    deps = [":conformance_pb", "//upb_zig/runtime:upb_zig"],
    zigopts = ["-lc"],
)

# Test that test_messages_proto3 compiles with all its dependencies
zig_test(
    name = "test_messages_proto3_compile",
    main = "test_proto3_compile.zig",
    deps = [
        ":zig_test_messages_proto3", 
        "//upb_zig/runtime:upb_zig"
    ],
    zigopts = ["-lc"],
)

# Conformance testee binary - implements the conformance testing protocol
# Reads ConformanceRequest from stdin, writes ConformanceResponse to stdout
# Uses generated Zig bindings to decode/encode test messages
zig_binary(
    name = "conformance_zig",
    testonly = True,
    main = "conformance.zig",
    deps = [
        "//upb_zig/runtime:upb_zig",
        ":zig_test_messages_proto3",
        ":zig_test_messages_proto2",
        ":zig_test_messages_proto3_editions",
        ":zig_test_messages_proto2_editions",
    ],
    zigopts = ["-lc"],
)

# Full conformance test suite

# note on expected failures, the contents of expected_failures.txt was copied
# wholesale from the conformance test target for upb in the protobuf repo
# there is no way we can guarantee something to work if it does not even work in the
# official implementation.

make_shell_script(
    name = "gen_test_conformance_upb_zig_dynamic_minitable",
    out = "test_conformance_upb_zig_dynamic_minitable.sh",
    contents = "$1 --maximum_edition 2023 --enforce_recommended --failure_list $2 $3",
)

sh_test(
    name = "conformance_test",
    srcs = ["test_conformance_upb_zig_dynamic_minitable.sh"],
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location :expected_failures.txt)",
        "$(location :conformance_zig)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        ":expected_failures.txt",
        ":conformance_zig",
    ],
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    tags = ["should_fail"],
)

##################################################################################
#                        Generate Conformance Report                             #
##################################################################################

# Python library for parsing conformance output and generating report (markdown table)
py_library(
    name = "conformance_report_lib",
    srcs = ["conformance_report.py"],
)

# Check that README conformance table is up to date
py_binary(
    name = "check_readme_conformance",
    srcs = ["check_readme_conformance.py"],
    deps = [":conformance_report_lib"],
)

make_shell_script(
    name = "gen_check_readme_conformance_test",
    out = "check_readme_conformance_test.sh",
    contents = "$1 --maximum_edition 2023 --enforce_recommended $2 2>&1 | $3 $4",
)

sh_test(
    name = "conformance_report_up_to_date",
    srcs = ["check_readme_conformance_test.sh"],
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location :conformance_zig)",
        "$(location :check_readme_conformance)",
        "$(location //:README.md)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        ":conformance_zig",
        ":check_readme_conformance",
        "//:README.md",
    ],
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    tags = ["doc_checking"],
)

# Update README.md with current conformance results
py_binary(
    name = "update_readme_conformance",
    srcs = ["update_readme_conformance.py"],
    deps = [":conformance_report_lib"],
    python_version = "PY3",
)

make_shell_script(
    name = "gen_update_readme_conformance",
    out = "update_readme_conformance.sh",
    contents = "$1 --maximum_edition 2023 --enforce_recommended $2 2>&1 | $3 ${BUILD_WORKSPACE_DIRECTORY}/README.md",
)

sh_binary(
    name = "update_conformance_report",
    srcs = ["update_readme_conformance.sh"],
    testonly = True,
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location :conformance_zig)",
        "$(location :update_readme_conformance)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        ":conformance_zig",
        ":update_readme_conformance",
    ],
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
)