load("//bazel:build_defs.bzl", "make_shell_script")
load("@rules_python//python:proto.bzl", "py_proto_library")
load("@com_google_protobuf//conformance:defs.bzl", "conformance_test")

# the idea here is to contrive a conformance testee that fails every single one of 
# the conformance tests which will allow us to capture a master list of all the tests
# IknowIknow... I really could not come up with a better solution.

# I only need to pull in conformance_py_pb2 for this one since I wont bother with 
# actually decoding the messages
py_proto_library(
    name = "conformance_py_pb2",
    deps = ["@com_google_protobuf//conformance:conformance_proto"],
    testonly = True
)

# Conformance testee binary that systematically fails all tests.
py_binary(
    name = "testee",
    main = "testee.py",
    srcs = ["testee.py"],
    deps = [
        ":conformance_py_pb2",
        "@rules_python//python/runfiles",
        "@pypi//protobuf"
    ],
    python_version = "PY3",
    testonly = True,
)

# genrule that runs the all fail testee, calling this all_tests because that 
# is what this used as.
genrule(
    name = "all_tests",
    outs = ["all_tests.txt"],
    tools = [":testee", "@com_google_protobuf//conformance:conformance_test_runner"],
    cmd = "$(location @com_google_protobuf//conformance:conformance_test_runner) --maximum_edition 2023 --enforce_recommended $(location :testee) > $@ 2>&1 || true",
    testonly = True,
)


# tool that converts test result.txt files to a more usable format
py_binary(
    name = "test_results_parser",
    main = "test_results_parser.py",
    srcs = ["test_results_parser.py"],
    data = [":all_tests"],
    python_version = "PY3",
    deps = ["@dev_pypi//click"],
    testonly = True,
)

genrule(
    name = "markdown_table",
    outs = ["conformance_results.md"],
    tools = [":test_results_parser"],
    srcs = [":all_tests", "//upb_zig/conformance:upb_fails", "//zig_protobuf/conformance:protobuf_zig_fails"],
    cmd = "$(location :test_results_parser) -a $(location :all_tests) --upb-fails $(location //upb_zig/conformance:upb_fails) --zig-pb-fails $(location //zig_protobuf/conformance:protobuf_zig_fails) > $@",
    testonly = True,
)
