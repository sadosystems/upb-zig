//! Test that the generated protobuf code compiles and types work correctly.
//! This test verifies the codegen produces valid Zig that compiles against the runtime types.

const std = @import("std");
const simple_pb = @import("simple_pb");

test "Person struct exists and has expected methods" {
    // Verify that Person struct exists
    const PersonType = simple_pb.Person;

    // Verify struct has expected API
    _ = PersonType.init;
    _ = PersonType.decode;
    _ = PersonType.encode;
    _ = @sizeOf(PersonType);
}

test "Status enum exists and has expected values" {
    const Status = simple_pb.Status;

    // Verify enum values
    try std.testing.expectEqual(@as(i32, 0), Status.UNKNOWN.toInt());
    try std.testing.expectEqual(@as(i32, 1), Status.ACTIVE.toInt());
    try std.testing.expectEqual(@as(i32, 2), Status.INACTIVE.toInt());

    // Verify fromInt works
    try std.testing.expectEqual(Status.ACTIVE, Status.fromInt(1).?);
    try std.testing.expectEqual(@as(?Status, null), Status.fromInt(99));
}

test "AddressBook struct exists" {
    const AddressBookType = simple_pb.AddressBook;

    // Verify struct has expected API
    _ = AddressBookType.init;
    _ = AddressBookType.decode;
    _ = AddressBookType.encode;
    _ = @sizeOf(AddressBookType);
}
