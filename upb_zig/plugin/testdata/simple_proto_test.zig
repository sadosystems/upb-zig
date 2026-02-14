//! Test that the generated protobuf code compiles and types work correctly.
//! This test verifies the codegen produces valid Zig that compiles against the runtime types.
//! This test this truly tests almost nothing.

const std = @import("std");
const upb = @import("upb_zig");
const simple_pb = @import("simple_zig_pb");

test "Person struct exists and has expected methods" {
    // Verify that Person struct exists
    const PersonType = simple_pb.Person;

    // Verify struct has expected API
    _ = PersonType.init;
    _ = PersonType.decode;
    _ = PersonType.encode;
    _ = @sizeOf(PersonType);

    const arena = try upb.Arena.init(std.heap.page_allocator);
    defer arena.deinit();

    var person = try simple_pb.Person.init(arena);
    person.setName("John");
    person.setId(99);
    var timestamp = try simple_pb.google_protobuf_timestamp.Timestamp.init(arena);
    // var timestamp = try timestamp_pb.Timestamp.init(arena);
    timestamp.setSeconds(12);
    timestamp.setNanos(333);

    person.setLastUpdated(timestamp);

}

test "Status enum exists and has expected values" {
    const PhoneType = simple_pb.PhoneType;

    // Verify enum values
    try std.testing.expectEqual(@as(i31, 0), PhoneType.PHONE_TYPE_UNSPECIFIED.toInt());

    try std.testing.expectEqual(@as(i31, 1), PhoneType.PHONE_TYPE_MOBILE.toInt());

    try std.testing.expectEqual(@as(i31, 2), PhoneType.PHONE_TYPE_HOME.toInt());

    try std.testing.expectEqual(@as(i31, 3), PhoneType.PHONE_TYPE_WORK.toInt());
}

test "AddressBook struct exists" {
    const AddressBookType = simple_pb.AddressBook;

    // Verify struct has expected API
    _ = AddressBookType.init;
    _ = AddressBookType.decode;
    _ = AddressBookType.encode;
    _ = @sizeOf(AddressBookType);
}
