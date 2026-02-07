load("//bazel:build_defs.bzl", "make_shell_script")
load("@rules_python//python:proto.bzl", "py_proto_library")
load("@com_google_protobuf//conformance:defs.bzl", "conformance_test")


# the idea here is to contrive a conformance testee that fails every single one of 
# the conformance tests which will allow us to capture a master list of all the tests
# IknowIknow... I really could not come up with a better solution. If you have one PR
# it pls.

py_proto_library(
    name = "conformance_py_pb2",
    deps = ["@com_google_protobuf//conformance:conformance_proto"],
    testonly = True
)
py_proto_library(
    name = "test_messages_proto3_py_pb2",
    deps = ["@com_google_protobuf//conformance/test_protos:test_messages_proto3_proto"],
    testonly = True
)

py_proto_library(
    name = "test_messages_proto2_py_pb2",
    deps = ["@com_google_protobuf//conformance/test_protos:test_messages_proto2_proto"],
    testonly = True
)

py_proto_library(
    name = "test_messages_proto3_editions_py_pb2",
    deps = ["@com_google_protobuf//conformance/test_protos:test_messages_proto3_editions_proto"],
    testonly = True
)

py_proto_library(
    name = "test_messages_proto2_editions_py_pb2",
    deps = ["@com_google_protobuf//conformance/test_protos:test_messages_proto2_editions_proto"],
    testonly = True
)

# Conformance testee binary that systematically fails all tests. It still 
# implements the conformance testing protocol (reads ConformanceRequest from 
# stdin, write ConformanceResponse to stdout) just to keep the tests moving
py_binary(
    name = "testee",
    main = "testee.py",
    srcs = ["testee.py"],
    testonly = True,
    deps = [
        ":conformance_py_pb2",
        ":test_messages_proto3_py_pb2",
        ":test_messages_proto2_py_pb2",
        ":test_messages_proto3_editions_py_pb2",
        ":test_messages_proto2_editions_py_pb2",
        "@com_google_protobuf//:protobuf_python",
    ],
    python_version = "PY3",
)

py_binary(
    name = "my_testee",
    main = "testee.py",
    srcs = ["testee.py"],
    testonly = True,
    deps = [
        ":conformance_py_pb2",
        "@rules_python//python/runfiles",
        "@pypi//protobuf"
    ],
    python_version = "PY3",
)



make_shell_script(
    name = "gen_test_conformance_all_fail",
    out = "test_conformance_all_fail.sh",
    contents = "$1 --maximum_edition 2023 --enforce_recommended $2",
)

genrule(
    name = "all_tests",
    testonly = True,
    outs = ["all_tests.txt"],
    tools = [":my_testee", "@com_google_protobuf//conformance:conformance_test_runner"],
    cmd = "$(location @com_google_protobuf//conformance:conformance_test_runner) --enforce_recommended $(location :my_testee) > $@ 2>&1 || true",
)


py_binary(
    name = "test_parse",
    main = "tests_parser.py",
    srcs = ["tests_parser.py"],
    data = [":all_tests"],
    testonly = True,
    python_version = "PY3",
    deps = ["@rules_python//python/runfiles"],
)
