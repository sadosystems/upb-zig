const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("upb_runtime", .{
        .root_source_file = b.path("upb_zig/runtime/re_export_everything.zig"),
        .target = target,
        .optimize = optimize,
    });

    const upb_zig_mod = b.addModule("upb_zig", .{
        .root_source_file = b.path("upb_zig/runtime/upb_zig.zig"),
        .target = target,
        .optimize = optimize,
    });

    const wkt = b.addModule("wkt", .{
        .root_source_file = b.path("upb_zig/runtime/re_export_well_known_types.zig"),
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("upb_zig", upb_zig_mod);
    mod.addImport("wkt", wkt);

    // Include paths for C headers.
    mod.addIncludePath(b.path("external/protobuf+"));
    mod.addIncludePath(b.path("upb_zig/runtime"));
    mod.addIncludePath(b.path("external/protobuf+/third_party/utf8_range"));
    // Generated protobuf headers (descriptor.upb.h etc.)
    mod.addIncludePath(b.path("generated"));
    // Pre-generated cmake minitable headers.
    mod.addIncludePath(b.path("external/protobuf+/upb/reflection/cmake"));

    // All C source files from upb and helpers.
    const c_sources = .{
        "external/protobuf+/upb/base/status.c",
        "external/protobuf+/upb/hash/common.c",
        "external/protobuf+/upb/json/decode.c",
        "external/protobuf+/upb/json/encode.c",
        "external/protobuf+/upb/lex/atoi.c",
        "external/protobuf+/upb/lex/round_trip.c",
        "external/protobuf+/upb/lex/strtod.c",
        "external/protobuf+/upb/lex/unicode.c",
        "external/protobuf+/upb/mem/alloc.c",
        "external/protobuf+/upb/mem/arena.c",
        "external/protobuf+/upb/message/accessors.c",
        "external/protobuf+/upb/message/array.c",
        "external/protobuf+/upb/message/compat.c",
        "external/protobuf+/upb/message/copy.c",
        "external/protobuf+/upb/message/internal/extension.c",
        "external/protobuf+/upb/message/internal/iterator.c",
        "external/protobuf+/upb/message/internal/message.c",
        "external/protobuf+/upb/message/map.c",
        "external/protobuf+/upb/message/map_sorter.c",
        "external/protobuf+/upb/message/merge.c",
        "external/protobuf+/upb/message/message.c",
        "external/protobuf+/upb/mini_descriptor/build_enum.c",
        "external/protobuf+/upb/mini_descriptor/decode.c",
        "external/protobuf+/upb/mini_descriptor/internal/base92.c",
        "external/protobuf+/upb/mini_descriptor/internal/encode.c",
        "external/protobuf+/upb/mini_descriptor/link.c",
        "external/protobuf+/upb/mini_table/extension_registry.c",
        "external/protobuf+/upb/mini_table/generated_registry.c",
        "external/protobuf+/upb/mini_table/internal/message.c",
        "external/protobuf+/upb/mini_table/message.c",
        "external/protobuf+/upb/reflection/def_pool.c",
        "external/protobuf+/upb/reflection/def_type.c",
        "external/protobuf+/upb/reflection/desc_state.c",
        "external/protobuf+/upb/reflection/enum_def.c",
        "external/protobuf+/upb/reflection/enum_reserved_range.c",
        "external/protobuf+/upb/reflection/enum_value_def.c",
        "external/protobuf+/upb/reflection/extension_range.c",
        "external/protobuf+/upb/reflection/field_def.c",
        "external/protobuf+/upb/reflection/file_def.c",
        "external/protobuf+/upb/reflection/internal/def_builder.c",
        "external/protobuf+/upb/reflection/internal/strdup2.c",
        "external/protobuf+/upb/reflection/message.c",
        "external/protobuf+/upb/reflection/message_def.c",
        "external/protobuf+/upb/reflection/message_reserved_range.c",
        "external/protobuf+/upb/reflection/method_def.c",
        "external/protobuf+/upb/reflection/oneof_def.c",
        "external/protobuf+/upb/reflection/service_def.c",
        "external/protobuf+/upb/wire/decode.c",
        "external/protobuf+/upb/wire/encode.c",
        "external/protobuf+/upb/wire/eps_copy_input_stream.c",
        "external/protobuf+/upb/wire/internal/decoder.c",
        "external/protobuf+/upb/wire/reader.c",
        "external/protobuf+/third_party/utf8_range/utf8_range.c",
        "upb_zig/runtime/upb_helpers.c",
        // Pre-generated descriptor minitable (defines google__protobuf__*_msg_init symbols
        // needed by the reflection API).
        "external/protobuf+/upb/reflection/cmake/google/protobuf/descriptor.upb_minitable.c",
    };

    inline for (c_sources) |c_file| {
        mod.addCSourceFile(.{ .file = b.path(c_file) });
    }

    mod.link_libc = true;

    const tests = b.addTest(.{
        .root_module = mod,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run upb_zig tests");
    test_step.dependOn(&run_tests.step);
}
