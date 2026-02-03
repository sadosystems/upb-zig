//! Test that the generated conformance protobuf code compiles and types work correctly.
//! This test verifies the codegen produces valid Zig that compiles against the runtime types.
//! This IS NOT AN ACTUAL CONFORMANCE TEST. the actual conformance test is implemented as a
//! shell script that pipes the output of the google conformance test harness to the zig 
//! conformance test harness.

const std = @import("std");
const conformance_pb = @import("conformance_conformance");
const upb_zig = @import("upb_zig");

// ============================================================================
// Enum Tests
// ============================================================================

test "WireFormat enum exists and has expected values" {
    const WireFormat = conformance_pb.WireFormat;

    try std.testing.expectEqual(@as(i32, 0), WireFormat.UNSPECIFIED.toInt());
    try std.testing.expectEqual(@as(i32, 1), WireFormat.PROTOBUF.toInt());
    try std.testing.expectEqual(@as(i32, 2), WireFormat.JSON.toInt());
    try std.testing.expectEqual(@as(i32, 3), WireFormat.JSPB.toInt());
    try std.testing.expectEqual(@as(i32, 4), WireFormat.TEXT_FORMAT.toInt());

    // Verify fromInt works
    try std.testing.expectEqual(WireFormat.PROTOBUF, WireFormat.fromInt(1).?);
    try std.testing.expectEqual(WireFormat.JSON, WireFormat.fromInt(2).?);
    try std.testing.expectEqual(@as(?conformance_pb.WireFormat, null), WireFormat.fromInt(99));
}

test "TestCategory enum exists and has expected values" {
    const TestCategory = conformance_pb.TestCategory;

    try std.testing.expectEqual(@as(i32, 0), TestCategory.UNSPECIFIED_TEST.toInt());
    try std.testing.expectEqual(@as(i32, 1), TestCategory.BINARY_TEST.toInt());
    try std.testing.expectEqual(@as(i32, 2), TestCategory.JSON_TEST.toInt());
    try std.testing.expectEqual(@as(i32, 3), TestCategory.JSON_IGNORE_UNKNOWN_PARSING_TEST.toInt());
    try std.testing.expectEqual(@as(i32, 4), TestCategory.JSPB_TEST.toInt());
    try std.testing.expectEqual(@as(i32, 5), TestCategory.TEXT_FORMAT_TEST.toInt());

    // Verify fromInt works
    try std.testing.expectEqual(TestCategory.BINARY_TEST, TestCategory.fromInt(1).?);
    try std.testing.expectEqual(@as(?conformance_pb.TestCategory, null), TestCategory.fromInt(99));
}

// ============================================================================
// Message Struct Tests
// ============================================================================

test "TestStatus struct exists and has expected methods" {
    const TestStatus = conformance_pb.TestStatus;

    // Verify struct has expected API
    _ = TestStatus.init;
    _ = TestStatus.decode;
    _ = TestStatus.encode;
    _ = @sizeOf(TestStatus);
}

test "FailureSet struct exists and has expected methods" {
    const FailureSet = conformance_pb.FailureSet;

    _ = FailureSet.init;
    _ = FailureSet.decode;
    _ = FailureSet.encode;
    _ = @sizeOf(FailureSet);
}

test "ConformanceRequest struct exists and has expected methods" {
    const ConformanceRequest = conformance_pb.ConformanceRequest;

    _ = ConformanceRequest.init;
    _ = ConformanceRequest.decode;
    _ = ConformanceRequest.encode;
    _ = @sizeOf(ConformanceRequest);
}

test "ConformanceResponse struct exists and has expected methods" {
    const ConformanceResponse = conformance_pb.ConformanceResponse;

    _ = ConformanceResponse.init;
    _ = ConformanceResponse.decode;
    _ = ConformanceResponse.encode;
    _ = @sizeOf(ConformanceResponse);
}

test "JspbEncodingConfig struct exists and has expected methods" {
    const JspbEncodingConfig = conformance_pb.JspbEncodingConfig;

    _ = JspbEncodingConfig.init;
    _ = JspbEncodingConfig.decode;
    _ = JspbEncodingConfig.encode;
    _ = @sizeOf(JspbEncodingConfig);
}

test "scalar field set/get roundtrip" {
    var arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    var request = try conformance_pb.ConformanceRequest.init(arena);

    request.setMessageType("protobuf_test_messages.proto3.TestAllTypesProto3");
    try std.testing.expectEqualStrings(
        "protobuf_test_messages.proto3.TestAllTypesProto3",
        request.getMessageType(),
    );

    request.setPrintUnknownFields(true);
    try std.testing.expect(request.getPrintUnknownFields());
}

test "enum field set/get roundtrip" {
    var arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    var request = try conformance_pb.ConformanceRequest.init(arena);

    request.setRequestedOutputFormat(.JSON);
    try std.testing.expectEqual(conformance_pb.WireFormat.JSON, request.getRequestedOutputFormat());

    request.setTestCategory(.BINARY_TEST);
    try std.testing.expectEqual(conformance_pb.TestCategory.BINARY_TEST, request.getTestCategory());
}

test "scalar field encode/decode roundtrip" {
    var arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    var request = try conformance_pb.ConformanceRequest.init(arena);
    request.setMessageType("test.MessageType");
    request.setRequestedOutputFormat(.PROTOBUF);
    request.setPrintUnknownFields(true);

    const encoded = try request.encode();

    var arena2 = try upb_zig.Arena.init(std.testing.allocator);
    defer arena2.deinit();

    const decoded = try conformance_pb.ConformanceRequest.decode(arena2, encoded);
    try std.testing.expectEqualStrings("test.MessageType", decoded.getMessageType());
    try std.testing.expectEqual(conformance_pb.WireFormat.PROTOBUF, decoded.getRequestedOutputFormat());
    try std.testing.expect(decoded.getPrintUnknownFields());
}

// ============================================================================
// Stub Tests - these exercise codegen features that are currently stubbed out.
// Each test targets a specific TODO in the generated code.
// ============================================================================

test "STUB: repeated field count after decode" {
    // Wire format for FailureSet with one TestStatus entry:
    //   field 2 (test), wire type 2 (len-delimited): tag = (2 << 3) | 2 = 18
    //   length = 11
    //   TestStatus:
    //     field 1 (name), wire type 2: tag = (1 << 3) | 2 = 10
    //     length = 9
    //     "test_name"
    const wire_data = "\x12\x0b\x0a\x09test_name";

    var arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    const failure_set = try conformance_pb.FailureSet.decode(arena, wire_data);

    // upb successfully decoded this - the data is in the upb_Message.
    // But testCount() is stubbed to always return 0.
    try std.testing.expect(failure_set.testCount() > 0);
}

test "STUB: repeated field add then count" {
    var arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    var failure_set = try conformance_pb.FailureSet.init(arena);
    var test_status = try conformance_pb.TestStatus.init(arena);
    test_status.setName("some_test");

    // addTest is stubbed as a no-op
    try failure_set.addTest(test_status);

    // testCount is stubbed to return 0
    try std.testing.expectEqual(@as(usize, 1), failure_set.testCount());
}

test "STUB: nested message getter after decode" {
    // Wire format for ConformanceRequest with jspb_encoding_options set:
    //   field 6 (jspb_encoding_options), wire type 2 (len-delimited): tag = (6 << 3) | 2 = 50
    //   length = 2
    //   JspbEncodingConfig:
    //     field 1 (use_jspb_array_any_format), wire type 0 (varint): tag = 8
    //     value = 1 (true)
    const wire_data = "\x32\x02\x08\x01";

    var arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    const request = try conformance_pb.ConformanceRequest.decode(arena, wire_data);

    // upb successfully decoded this - the nested message is in the upb_Message.
    // But getJspbEncodingOptions() is stubbed to always return null.
    try std.testing.expect(request.getJspbEncodingOptions() != null);
}

test "STUB: nested message setter then getter" {
    var arena = try upb_zig.Arena.init(std.testing.allocator);
    defer arena.deinit();

    var config = try conformance_pb.JspbEncodingConfig.init(arena);
    config.setUseJspbArrayAnyFormat(true);

    var request = try conformance_pb.ConformanceRequest.init(arena);

    // setJspbEncodingOptions is stubbed as a no-op
    request.setJspbEncodingOptions(&config);

    // getJspbEncodingOptions is stubbed to return null
    try std.testing.expect(request.getJspbEncodingOptions() != null);
}