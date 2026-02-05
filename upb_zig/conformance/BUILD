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

# Test that the generated conformance proto code compiles and types work correctly
zig_test(
    name = "conformance_protos_test",
    main = "conformance_protos.zig",
    deps = [":conformance_pb", "//upb_zig/runtime:upb_zig"],
    zigopts = ["-lc"],
)

# Test that transitive dependencies resolve correctly
zig_test(
    name = "transitive_deps_test",
    main = "transitive_deps.zig",
    deps = [":zig_test_messages_proto3", "//upb_zig/runtime:upb_zig"],
    zigopts = ["-lc"],
)

# Conformance testee binary - implements the conformance testing protocol
# Reads ConformanceRequest from stdin, writes ConformanceResponse to stdout
# Uses generated Zig bindings to decode/encode test messages
zig_binary(
    name = "testee",
    testonly = True,
    main = "conformance_testee.zig",
    deps = [
        "//upb_zig/runtime:upb_zig",
        ":conformance_pb",
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
    name = "conformance",
    srcs = ["test_conformance_upb_zig_dynamic_minitable.sh"],
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location :expected_failures.txt)",
        "$(location testee)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        ":expected_failures.txt",
        ":testee",
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

make_shell_script(
    name = "gen_check_readme_conformance_test",
    out = "check_readme_conformance_test.sh",
    # $1=conformance_test_runner $2=conformance_zig $3=check_readme_conformance
    # $4=README.md $5=zig_protobuf_expected_failures $6=protobuf_zig_testee
    contents = "UPB_LOG=$(mktemp) && ZIG_LOG=$(mktemp) && trap 'rm -f \"$UPB_LOG\" \"$ZIG_LOG\"' EXIT; $1 --maximum_edition 2023 --enforce_recommended $2 > \"$UPB_LOG\" 2>&1; $1 --failure_list $5 $6 > \"$ZIG_LOG\" 2>&1; cat \"$UPB_LOG\" | $3 $4 --zig-protobuf-log \"$ZIG_LOG\"",
)

sh_test(
    name = "conformance_report_up_to_date",
    srcs = ["check_readme_conformance_test.sh"],
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location testee)",
        "$(location //conformance:check_readme_conformance)",
        "$(location //:README.md)",
        "$(location //zig_protobuf/conformance:expected_failures.txt)",
        "$(location //zig_protobuf/conformance:protobuf_zig_testee)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        ":testee",
        "//conformance:check_readme_conformance",
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
    # $1=conformance_test_runner $2=conformance_zig $3=update_readme_conformance
    # $4=zig_protobuf_expected_failures $5=protobuf_zig_testee
    contents = "UPB_LOG=$(mktemp) && ZIG_LOG=$(mktemp) && trap 'rm -f \"$UPB_LOG\" \"$ZIG_LOG\"' EXIT; $1 --maximum_edition 2023 --enforce_recommended $2 > \"$UPB_LOG\" 2>&1; $1 --failure_list $4 $5 > \"$ZIG_LOG\" 2>&1; cat \"$UPB_LOG\" | $3 ${BUILD_WORKSPACE_DIRECTORY}/README.md --zig-protobuf-log \"$ZIG_LOG\"",
)

sh_binary(
    name = "update_conformance_report",
    srcs = ["update_readme_conformance.sh"],
    testonly = True,
    args = [
        "$(location @com_google_protobuf//conformance:conformance_test_runner)",
        "$(location testee)",
        "$(location //conformance:update_readme_conformance)",
        "$(location //zig_protobuf/conformance:expected_failures.txt)",
        "$(location //zig_protobuf/conformance:protobuf_zig_testee)",
    ],
    data = [
        "@com_google_protobuf//conformance:conformance_test_runner",
        ":testee",
        "//conformance:update_readme_conformance",
        "//zig_protobuf/conformance:expected_failures.txt",
        "//zig_protobuf/conformance:protobuf_zig_testee",
    ],
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
)