const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("upb_zig", .{
        .root_source_file = b.path("upb_zig.zig"),
        .target = target,
        .optimize = optimize,
    });

    mod.addIncludePath(b.path("."));
    mod.addCSourceFile(.{ .file = b.path("upb_helpers.c") });
    mod.link_libc = true;
}
