//! Test that the generated conformance protobuf code compiles and types work correctly.
//! This test verifies the codegen produces valid Zig that compiles against the runtime types.
//! This IS NOT AN ACTUAL CONFORMANCE TEST. the actual conformance test is implemented as a
//! shell script that pipes the output of the google conformance test harness to the zig 
//! conformance test harness.

const std = @import("std");
const conformance_pb = @import("conformance_conformance");

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