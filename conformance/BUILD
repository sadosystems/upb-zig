load("//bazel:build_defs.bzl", "make_shell_script")

##################################################################################
#                       Conformance Report Generation                            #
##################################################################################

# tool that converts test result.txt files to a more usable format
py_binary(
    name = "test_results_parser",
    main = "test_results_parser.py",
    srcs = ["test_results_parser.py"],
    python_version = "PY3",
    deps = ["@dev_pypi//click"],
    testonly = True,
)

genrule(
    name = "markdown_table",
    outs = ["conformance_results.md"],
    tools = [":test_results_parser"],
    srcs = [
        "//conformance/all_fail_testee:all_tests",
        "//upb_zig/conformance:upb_fails", 
        "//zig_protobuf/conformance:protobuf_zig_fails"
    ],
    cmd = "$(location :test_results_parser) gen_table " + 
    "--all-tests $(location //conformance/all_fail_testee:all_tests) " +
    "--upb-fails $(location //upb_zig/conformance:upb_fails) " +
    "--zig-pb-fails $(location //zig_protobuf/conformance:protobuf_zig_fails) " +
    "> $@",
    testonly = True,
)

make_shell_script(
    name = "update_script",
    out = "update.sh",
    contents = "$1 update --readme ${BUILD_WORKSPACE_DIRECTORY}/README.md --table $2",
)

sh_binary(
    name = "update_report",
    srcs = ["update.sh"],
    args = [
        "$(location :test_results_parser)",
        "$(location :markdown_table)",
    ],
    data = [
        ":test_results_parser",
        ":markdown_table",
    ],
    testonly = True,
)

make_shell_script(
    name = "up_to_date_script",
    out = "up_to_date.sh",
    contents = "$1 up-to-date --readme $2 --table $3",
)

sh_test(
    name = "readme_table_is_up_to_date",
    srcs = ["up_to_date.sh"],
    args = [
        "$(location :test_results_parser)",
        "$(location //:README.md)",
        "$(location :markdown_table)",
    ],
    data = [
        ":test_results_parser",
        "//:README.md",
        ":markdown_table",
    ],
    tags = ["doc_checking"],
    testonly = True,
)