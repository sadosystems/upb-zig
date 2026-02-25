const std = @import("std");
pub const upb_zig = @import("upb_zig");
pub const wkt = @import("wkt");

test "Does Anything Work" {
    const arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    // If we got here, arena was created successfully (init() would have returned error otherwise)
    // Just verify the raw pointer accessor works
    _ = arena.raw();
}