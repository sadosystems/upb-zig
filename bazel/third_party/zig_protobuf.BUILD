load("@rules_zig//zig:defs.bzl", "zig_library", "zig_binary")

package(default_visibility = ["//visibility:public"])

# zig-protobuf runtime library
zig_library(
    name = "protobuf",
    main = "src/protobuf.zig",
    srcs = [
        "src/wire.zig",
        "src/json.zig",
    ],
)

# zig-protobuf protoc-gen-zig plugin
zig_binary(
    name = "protoc-gen-zig",
    main = "bootstrapped-generator/main.zig",
    srcs = [
        "bootstrapped-generator/FullName.zig",
        "bootstrapped-generator/google/protobuf.pb.zig",
        "bootstrapped-generator/google/protobuf/compiler.pb.zig",
    ],
    deps = [":protobuf"],
)

# Generate conformance proto bindings using zig-protobuf's protoc-gen-zig.
# All protos are generated in a single invocation so cross-package imports resolve.
genrule(
    name = "conformance_zig_protos",
    srcs = [
        "@com_google_protobuf//conformance:conformance_proto",
        "@com_google_protobuf//conformance/test_protos:test_messages_proto3_proto",
        "@com_google_protobuf//conformance/test_protos:test_messages_proto2_proto",
        "@com_google_protobuf//:any_proto",
        "@com_google_protobuf//:duration_proto",
        "@com_google_protobuf//:empty_proto",
        "@com_google_protobuf//:field_mask_proto",
        "@com_google_protobuf//:struct_proto",
        "@com_google_protobuf//:timestamp_proto",
        "@com_google_protobuf//:wrappers_proto",
    ],
    outs = [
        "conformance.pb.zig",
        "protobuf_test_messages/proto3.pb.zig",
        "protobuf_test_messages/proto2.pb.zig",
        "google/protobuf.pb.zig",
    ],
    cmd = """
        $(location @com_google_protobuf//:protoc) \
            --plugin=protoc-gen-zig=$(location :protoc-gen-zig) \
            --zig_out=$(@D) \
            -I$$(dirname $$(dirname $(location @com_google_protobuf//conformance:conformance_proto))) \
            -I$$(dirname $$(dirname $$(dirname $(location @com_google_protobuf//:any_proto)))) \
            $(location @com_google_protobuf//conformance:conformance_proto) \
            $(location @com_google_protobuf//conformance/test_protos:test_messages_proto3_proto) \
            $(location @com_google_protobuf//conformance/test_protos:test_messages_proto2_proto)
    """,
    tools = [
        "@com_google_protobuf//:protoc",
        ":protoc-gen-zig",
    ],
)
