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
