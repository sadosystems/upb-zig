//! Conformance test harness for upb_zig.
//!
//! This implements the conformance testing protocol defined in conformance.proto.
//! It reads ConformanceRequest messages from stdin and writes ConformanceResponse
//! messages to stdout using the length-prefixed wire protocol.
//!
//! The request/response protocol messages are decoded/encoded using generated Zig
//! bindings from conformance.proto. The actual test messages (TestAllTypesProto3/Proto2)
//! are decoded and re-encoded to validate the implementation.

const std = @import("std");
const upb_zig = @import("upb_zig");
const conformance_pb = @import("conformance_conformance");

// Import generated proto modules for the test messages
const proto3 = @import("google_protobuf_test_messages_proto3");
const proto2 = @import("google_protobuf_test_messages_proto2");
const proto3_editions = @import("editions_golden_test_messages_proto3_editions");
const proto2_editions = @import("editions_golden_test_messages_proto2_editions");

/// Read exactly `len` bytes from a file descriptor into `buf`.
fn readFullyFd(fd: std.posix.fd_t, buf: []u8) !void {
    var total_read: usize = 0;
    while (total_read < buf.len) {
        const n = std.posix.read(fd, buf[total_read..]) catch |err| {
            return err;
        };
        if (n == 0) return error.EndOfStream;
        total_read += n;
    }
}

/// Write all bytes to a file descriptor.
fn writeFullyFd(fd: std.posix.fd_t, buf: []const u8) !void {
    var total_written: usize = 0;
    while (total_written < buf.len) {
        const n = std.posix.write(fd, buf[total_written..]) catch |err| {
            return err;
        };
        total_written += n;
    }
}

/// Process a single conformance request and produce a response.
fn runTest(req: conformance_pb.ConformanceRequest, arena: upb_zig.Arena) conformance_pb.ConformanceResponse {
    // Determine input format via oneof
    const payload_case = req.payloadCase();

    const is_protobuf_input = payload_case == .protobuf_payload;
    const is_json_input = payload_case == .json_payload;

    if (!is_protobuf_input and !is_json_input) {
        return switch (payload_case) {
            .text_payload => makeSkipped(arena, "Text format input not supported"),
            .jspb_payload => makeSkipped(arena, "JSPB input not supported"),
            else => makeRuntimeError(arena, "No payload provided in request"),
        };
    }

    // Check output format
    const output_format = req.getRequestedOutputFormat();
    const is_protobuf_output = output_format == .PROTOBUF or output_format == .UNSPECIFIED;
    const is_json_output = output_format == .JSON;

    if (!is_protobuf_output and !is_json_output) {
        return switch (output_format) {
            .JSPB => makeSkipped(arena, "JSPB output not supported"),
            .TEXT_FORMAT => makeSkipped(arena, "Text format output not supported"),
            else => makeSkipped(arena, "Unknown output format"),
        };
    }

    // Determine JSON decode options based on test category
    const test_category = req.getTestCategory();
    const json_decode_opts = upb_zig.JsonDecodeOptions{
        .ignore_unknown = (test_category == .JSON_IGNORE_UNKNOWN_PARSING_TEST),
    };

    const payload = if (is_protobuf_input) req.getProtobufPayload() else req.getJsonPayload();
    const message_type = req.getMessageType();

    // Process based on message type
    if (std.mem.eql(u8, message_type, "protobuf_test_messages.proto3.TestAllTypesProto3")) {
        return doRoundTrip(proto3.TestAllTypesProto3, arena, payload, is_protobuf_input, is_protobuf_output, json_decode_opts);
    } else if (std.mem.eql(u8, message_type, "protobuf_test_messages.proto2.TestAllTypesProto2")) {
        return doRoundTrip(proto2.TestAllTypesProto2, arena, payload, is_protobuf_input, is_protobuf_output, json_decode_opts);
    } else if (std.mem.eql(u8, message_type, "protobuf_test_messages.editions.proto3.TestAllTypesProto3")) {
        return doRoundTrip(proto3_editions.TestAllTypesProto3, arena, payload, is_protobuf_input, is_protobuf_output, json_decode_opts);
    } else if (std.mem.eql(u8, message_type, "protobuf_test_messages.editions.proto2.TestAllTypesProto2")) {
        return doRoundTrip(proto2_editions.TestAllTypesProto2, arena, payload, is_protobuf_input, is_protobuf_output, json_decode_opts);
    } else {
        return makeSkipped(arena, "Unsupported message type");
    }
}

/// Decode a test message, re-encode it in the requested format, and build a ConformanceResponse.
fn doRoundTrip(
    comptime MsgType: type,
    arena: upb_zig.Arena,
    payload: []const u8,
    is_protobuf_input: bool,
    is_protobuf_output: bool,
    json_decode_opts: upb_zig.JsonDecodeOptions,
) conformance_pb.ConformanceResponse {
    // Decode
    const msg = if (is_protobuf_input)
        MsgType.decode(arena, payload) catch {
            return makeParseError(arena, "Failed to decode from protobuf");
        }
    else
        MsgType.decodeJson(arena, payload, json_decode_opts) catch {
            return makeParseError(arena, "Failed to decode from JSON");
        };

    // Encode to requested format
    if (is_protobuf_output) {
        const encoded = msg.encode() catch {
            return makeSerializeError(arena, "Failed to encode to protobuf");
        };
        var resp = conformance_pb.ConformanceResponse.init(arena) catch {
            return makeRuntimeError(arena, "Failed to create response");
        };
        resp.setProtobufPayload(encoded);
        return resp;
    } else {
        const encoded = msg.encodeJson(.{}) catch {
            return makeSerializeError(arena, "Failed to encode to JSON");
        };
        var resp = conformance_pb.ConformanceResponse.init(arena) catch {
            return makeRuntimeError(arena, "Failed to create response");
        };
        resp.setJsonPayload(encoded);
        return resp;
    }
}

// --- Response helpers ---

fn makeSkipped(arena: upb_zig.Arena, msg: []const u8) conformance_pb.ConformanceResponse {
    var resp = conformance_pb.ConformanceResponse.init(arena) catch return undefined;
    resp.setSkipped(msg);
    return resp;
}

fn makeParseError(arena: upb_zig.Arena, msg: []const u8) conformance_pb.ConformanceResponse {
    var resp = conformance_pb.ConformanceResponse.init(arena) catch return undefined;
    resp.setParseError(msg);
    return resp;
}

fn makeRuntimeError(arena: upb_zig.Arena, msg: []const u8) conformance_pb.ConformanceResponse {
    var resp = conformance_pb.ConformanceResponse.init(arena) catch return undefined;
    resp.setRuntimeError(msg);
    return resp;
}

fn makeSerializeError(arena: upb_zig.Arena, msg: []const u8) conformance_pb.ConformanceResponse {
    var resp = conformance_pb.ConformanceResponse.init(arena) catch return undefined;
    resp.setSerializeError(msg);
    return resp;
}

/// Serve a single conformance request from stdin, write response to stdout.
/// Returns true if we should continue processing, false on EOF.
fn serveConformanceRequest(allocator: std.mem.Allocator) !bool {
    const stdin = std.posix.STDIN_FILENO;
    const stdout = std.posix.STDOUT_FILENO;

    // Read 4-byte little-endian length prefix
    var len_buf: [4]u8 = undefined;
    readFullyFd(stdin, &len_buf) catch |err| {
        if (err == error.EndOfStream) return false;
        return err;
    };
    const in_len = std.mem.readInt(u32, &len_buf, .little);

    if (in_len == 0) {
        return false;
    }

    // Read the serialized request
    const request_data = try allocator.alloc(u8, in_len);
    defer allocator.free(request_data);
    try readFullyFd(stdin, request_data);

    // Create arena for this request/response cycle
    var arena = try upb_zig.Arena.init(allocator);
    defer arena.deinit();

    // Decode request using generated conformance proto
    const request = conformance_pb.ConformanceRequest.decode(arena, request_data) catch {
        var resp = try conformance_pb.ConformanceResponse.init(arena);
        resp.setRuntimeError("Failed to parse ConformanceRequest");
        const encoded = try resp.encode();
        var out_len_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &out_len_buf, @intCast(encoded.len), .little);
        try writeFullyFd(stdout, &out_len_buf);
        try writeFullyFd(stdout, encoded);
        return true;
    };

    // Process the request
    const response = runTest(request, arena);

    // Encode and write response
    const response_bytes = response.encode() catch {
        // Last resort: if we can't even encode the response, write an empty response
        var out_len_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &out_len_buf, 0, .little);
        try writeFullyFd(stdout, &out_len_buf);
        return true;
    };

    var out_len_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &out_len_buf, @intCast(response_bytes.len), .little);
    try writeFullyFd(stdout, &out_len_buf);
    try writeFullyFd(stdout, response_bytes);

    return true;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var total_runs: usize = 0;

    while (true) {
        const should_continue = serveConformanceRequest(allocator) catch |err| {
            std.log.err("Error serving request: {}", .{err});
            return err;
        };

        if (!should_continue) {
            break;
        }

        total_runs += 1;
    }

    std.log.info("conformance-zig: received EOF from test runner after {} tests", .{total_runs});
}
