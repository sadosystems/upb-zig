load("//bazel:build_defs.bzl", "make_shell_script")
load("@rules_python//python:proto.bzl", "py_proto_library")


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
# py_binary(
#     name = "testee",
#     main = "all_fail_testee.py",
#     srcs = ["all_fail_testee.py"],
#     testonly = True,
#     deps = [
#         "conformance_py_pb2",
#         "test_messages_proto3_py_pb2",
#         "test_messages_proto2_py_pb2",
#         "test_messages_proto3_editions_py_pb2",
#         "test_messages_proto2_editions_py_pb2",
#         "@pypi//protobuf",
#     ],
#     python_version = "PY3",
# )

make_shell_script(
    name = "gen_test_conformance_all_fail",
    out = "test_conformance_all_fail.sh",
    contents = "$1 --maximum_edition 2023 --enforce_recommended $3",
)

genrule(
    name = "all_tests",
    srcs = [
        "@com_google_protobuf//conformance:conformance_test_runner",
    ],
    testonly = True,
    outs = ["all.txt"],
    cmd = " $(location @com_google_protobuf//conformance:conformance_test_runner) > $@",
)

py_binary(
    name = "all_fail_parse",
    main = "all_fail_parse.py",
    srcs = ["all_fail_parse.py"],
    data = ["@com_google_protobuf//conformance:conformance_test_runner"],
    testonly = True,
    python_version = "PY3",
    deps = ["@rules_python//python/runfiles"],
)
