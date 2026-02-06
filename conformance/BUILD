load("//bazel:build_defs.bzl", "make_shell_script")

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

# Update README.md with current conformance results
py_binary(
    name = "update_readme_conformance",
    srcs = ["update_readme_conformance.py"],
    deps = [":conformance_report_lib"],
    python_version = "PY3",
)

##################################################################################
#                        Generate Conformance Report                             #
##################################################################################

make_shell_script(
    name = "gen_check_readme_conformance_test",
    out = "check_readme_conformance_test.sh",
    # $1=conformance_test_runner $2=upb_zig_testee $3=check_readme_conformance
    # $4=README.md $5=zig_protobuf_expected_failures $6=protobuf_zig_testee
    contents = "UPB_LOG=$(mktemp) && ZIG_LOG=$(mktemp) && trap 'rm -f \"$UPB_LOG\" \"$ZIG_LOG\"' EXIT; $1 --maximum_edition 2023 --enforce_recommended $2 > \"$UPB_LOG\" 2>&1; $1 --failure_list $5 $6 > \"$ZIG_LOG\" 2>&1; cat \"$UPB_LOG\" | $3 $4 --zig-protobuf-log \"$ZIG_LOG\"",
)

sh_test(
    name = "conformance_report_up_to_date",
    srcs = ["check_readme_conformance_test.sh"],
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location //upb_zig/conformance:testee)",
        "$(location :check_readme_conformance)",
        "$(location //:README.md)",
        "$(location //zig_protobuf/conformance:expected_failures.txt)",
        "$(location //zig_protobuf/conformance:protobuf_zig_testee)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        "//upb_zig/conformance:testee",
        ":check_readme_conformance",
        "//:README.md",
        "//zig_protobuf/conformance:expected_failures.txt",
        "//zig_protobuf/conformance:protobuf_zig_testee",
    ],
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    tags = ["doc_checking"],
)

make_shell_script(
    name = "gen_update_readme_conformance",
    out = "update_readme_conformance.sh",
    # $1=conformance_test_runner $2=upb_zig_testee $3=update_readme_conformance
    # $4=zig_protobuf_expected_failures $5=protobuf_zig_testee
    contents = "UPB_LOG=$(mktemp) && ZIG_LOG=$(mktemp) && trap 'rm -f \"$UPB_LOG\" \"$ZIG_LOG\"' EXIT; $1 --maximum_edition 2023 --enforce_recommended $2 > \"$UPB_LOG\" 2>&1; $1 --failure_list $4 $5 > \"$ZIG_LOG\" 2>&1; cat \"$UPB_LOG\" | $3 ${BUILD_WORKSPACE_DIRECTORY}/README.md --zig-protobuf-log \"$ZIG_LOG\"",
)

sh_binary(
    name = "update_conformance_report",
    srcs = ["update_readme_conformance.sh"],
    testonly = True,
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location //upb_zig/conformance:testee)",
        "$(location :update_readme_conformance)",
        "$(location //zig_protobuf/conformance:expected_failures.txt)",
        "$(location //zig_protobuf/conformance:protobuf_zig_testee)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        "//upb_zig/conformance:testee",
        ":update_readme_conformance",
        "//zig_protobuf/conformance:expected_failures.txt",
        "//zig_protobuf/conformance:protobuf_zig_testee",
    ],
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
)
