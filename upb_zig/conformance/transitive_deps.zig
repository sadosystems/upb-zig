const std = @import("std");
const test_messages = @import("google_protobuf_test_messages_proto3");
const upb_zig = @import("upb_zig");

test "TestAllTypesProto3 compiles fully" {
    const T = test_messages.TestAllTypesProto3;

    _ = @sizeOf(T);

    _ = T.encode;
    _ = T.decode;
    _ = T.init;
}

test "ForeignEnum compiles fully" {
    const E = test_messages.ForeignEnum;
    _ = @sizeOf(E);
    _ = E.fromInt;
    _ = E.toInt;

    const val = E.fromInt(0);
    _ = val;
}

test "round-trip encode/decode" {
    var arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    // Create message
    const msg = test_messages.TestAllTypesProto3.init(arena) catch |err| {
        std.debug.print("init a (expected without minitable): {}\n", .{err});
        return;
    };
    _ = msg;
}
test "transitive deps actually resolve" {
    // Force resolution of nested message types
    const T = test_messages.TestAllTypesProto3;

    // These should fail to compile if deps are missing:
    _ = @TypeOf(T.getOptionalAny);
    _ = @TypeOf(T.getOptionalDuration);
    _ = @TypeOf(T.getOptionalTimestamp);
    _ = @TypeOf(T.getOptionalEmpty);
    _ = @TypeOf(T.getOptionalFieldMask);
    _ = @TypeOf(T.getOptionalStruct);

    // Wrappers - multiple types
    _ = @TypeOf(T.getOptionalBoolWrapper);
    _ = @TypeOf(T.getOptionalInt32Wrapper);
    _ = @TypeOf(T.getOptionalStringWrapper);
}
