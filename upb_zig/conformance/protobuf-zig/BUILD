load("@rules_zig//zig:defs.bzl", "zig_library", "zig_binary", "zig_test")

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


