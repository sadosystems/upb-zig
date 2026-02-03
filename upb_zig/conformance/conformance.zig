//! Conformance test harness for upb_zig.
//!
//! This implements the conformance testing protocol defined in conformance.proto.
//! It reads ConformanceRequest messages from stdin and writes ConformanceResponse
//! messages to stdout using the length-prefixed wire protocol.
//!
//! The conformance protocol messages are manually parsed, but the actual test
//! message (TestAllTypesProto3/Proto2) is decoded and re-encoded using our
//! generated Zig bindings to validate the implementation.

const std = @import("std");
const upb_zig = @import("upb_zig");

// Import generated proto modules for the test messages
const proto3 = @import("google_protobuf_test_messages_proto3");
const proto2 = @import("google_protobuf_test_messages_proto2");
const proto3_editions = @import("editions_golden_test_messages_proto3_editions");
const proto2_editions = @import("editions_golden_test_messages_proto2_editions");

/// Wire types in protobuf encoding
const WireType = enum(u3) {
    varint = 0,
    i64 = 1,
    len = 2,
    sgroup = 3,
    egroup = 4,
    i32 = 5,
};

/// ConformanceRequest payload types (oneof)
const PayloadCase = enum {
    none,
    protobuf_payload, // field 1
    json_payload, // field 2
    jspb_payload, // field 7
    text_payload, // field 8
};

/// Parsed ConformanceRequest
const ConformanceRequest = struct {
    payload_case: PayloadCase = .none,
    payload: []const u8 = "",
    requested_output_format: i32 = 0,
    message_type: []const u8 = "",
    test_category: i32 = 0,
};

/// Read a varint from a buffer, return the value and bytes consumed
fn readVarint(data: []const u8) !struct { value: u64, consumed: usize } {
    var value: u64 = 0;
    var shift: u6 = 0;
    for (data, 0..) |byte, i| {
        value |= @as(u64, byte & 0x7f) << shift;
        if (byte & 0x80 == 0) {
            return .{ .value = value, .consumed = i + 1 };
        }
        shift +%= 7;
        if (shift >= 64) return error.VarintTooLong;
    }
    return error.UnexpectedEof;
}

/// Parse a ConformanceRequest from wire format
fn parseConformanceRequest(data: []const u8) !ConformanceRequest {
    var req = ConformanceRequest{};
    var pos: usize = 0;

    while (pos < data.len) {
        // Read tag
        const tag_result = try readVarint(data[pos..]);
        pos += tag_result.consumed;

        const field_num: u32 = @intCast(tag_result.value >> 3);
        const wire_type: u3 = @intCast(tag_result.value & 0x7);

        switch (wire_type) {
            @intFromEnum(WireType.varint) => {
                const val_result = try readVarint(data[pos..]);
                pos += val_result.consumed;

                switch (field_num) {
                    3 => req.requested_output_format = @intCast(val_result.value),
                    5 => req.test_category = @intCast(val_result.value),
                    else => {}, // skip unknown varint fields
                }
            },
            @intFromEnum(WireType.len) => {
                const len_result = try readVarint(data[pos..]);
                pos += len_result.consumed;
                const len: usize = @intCast(len_result.value);

                if (pos + len > data.len) return error.UnexpectedEof;
                const field_data = data[pos .. pos + len];
                pos += len;

                switch (field_num) {
                    1 => {
                        req.payload_case = .protobuf_payload;
                        req.payload = field_data;
                    },
                    2 => {
                        req.payload_case = .json_payload;
                        req.payload = field_data;
                    },
                    4 => req.message_type = field_data,
                    7 => {
                        req.payload_case = .jspb_payload;
                        req.payload = field_data;
                    },
                    8 => {
                        req.payload_case = .text_payload;
                        req.payload = field_data;
                    },
                    else => {}, // skip unknown length-delimited fields
                }
            },
            @intFromEnum(WireType.i64) => {
                pos += 8; // skip 64-bit fixed
            },
            @intFromEnum(WireType.i32) => {
                pos += 4; // skip 32-bit fixed
            },
            else => return error.UnsupportedWireType,
        }
    }

    return req;
}

/// Write a varint to a buffer, return bytes written
fn writeVarint(value: u64, buf: []u8) usize {
    var v = value;
    var i: usize = 0;
    while (v >= 0x80) : (i += 1) {
        buf[i] = @intCast((v & 0x7f) | 0x80);
        v >>= 7;
    }
    buf[i] = @intCast(v);
    return i + 1;
}

/// Encode a "skipped" ConformanceResponse
/// Field 5, wire type 2 (length-delimited string)
fn encodeSkippedResponse(message: []const u8, buf: []u8) usize {
    // Tag: (5 << 3) | 2 = 42
    buf[0] = 42;
    var pos: usize = 1;

    // Length as varint
    pos += writeVarint(message.len, buf[pos..]);

    // String data
    @memcpy(buf[pos .. pos + message.len], message);
    pos += message.len;

    return pos;
}

/// Encode an empty "protobuf_payload" ConformanceResponse (will fail tests)
/// Field 3, wire type 2 (length-delimited bytes), length 0
fn encodeEmptyProtobufResponse(buf: []u8) usize {
    // Tag: (3 << 3) | 2 = 26
    buf[0] = 26;
    // Length: 0
    buf[1] = 0;
    return 2;
}

/// Encode an empty "json_payload" ConformanceResponse (will fail tests)
/// Field 4, wire type 2 (length-delimited string), length 0
fn encodeEmptyJsonResponse(buf: []u8) usize {
    // Tag: (4 << 3) | 2 = 34
    buf[0] = 34;
    // Length: 0
    buf[1] = 0;
    return 2;
}

/// Encode an empty "text_payload" ConformanceResponse (will fail tests)
/// Field 8, wire type 2 (length-delimited string), length 0
fn encodeEmptyTextResponse(buf: []u8) usize {
    // Tag: (8 << 3) | 2 = 66
    buf[0] = 66;
    // Length: 0
    buf[1] = 0;
    return 2;
}

/// Encode a "parse_error" ConformanceResponse
/// Field 1, wire type 2 (length-delimited string)
fn encodeParseErrorResponse(message: []const u8, buf: []u8) usize {
    // Tag: (1 << 3) | 2 = 10
    buf[0] = 10;
    var pos: usize = 1;

    // Length as varint
    pos += writeVarint(message.len, buf[pos..]);

    // String data
    @memcpy(buf[pos .. pos + message.len], message);
    pos += message.len;

    return pos;
}

/// Encode a "runtime_error" ConformanceResponse
/// Field 2, wire type 2 (length-delimited string)
fn encodeErrorResponse(message: []const u8, buf: []u8) usize {
    // Tag: (2 << 3) | 2 = 18
    buf[0] = 18;
    var pos: usize = 1;

    // Length as varint
    pos += writeVarint(message.len, buf[pos..]);

    // String data
    @memcpy(buf[pos .. pos + message.len], message);
    pos += message.len;

    return pos;
}

/// Encode a "serialize_error" ConformanceResponse
/// Field 6, wire type 2 (length-delimited string)
fn encodeSerializeErrorResponse(message: []const u8, buf: []u8) usize {
    // Tag: (6 << 3) | 2 = 50
    buf[0] = 50;
    var pos: usize = 1;

    // Length as varint
    pos += writeVarint(message.len, buf[pos..]);

    // String data
    @memcpy(buf[pos .. pos + message.len], message);
    pos += message.len;

    return pos;
}

/// Encode a "protobuf_payload" ConformanceResponse with actual data
/// Field 3, wire type 2 (length-delimited bytes)
fn encodeProtobufResponse(data: []const u8, buf: []u8) usize {
    // Tag: (3 << 3) | 2 = 26
    buf[0] = 26;
    var pos: usize = 1;

    // Length as varint
    pos += writeVarint(data.len, buf[pos..]);

    // Bytes data
    @memcpy(buf[pos .. pos + data.len], data);
    pos += data.len;

    return pos;
}

/// Encode a "json_payload" ConformanceResponse with actual data
/// Field 4, wire type 2 (length-delimited string)
fn encodeJsonResponse(data: []const u8, buf: []u8) usize {
    // Tag: (4 << 3) | 2 = 34
    buf[0] = 34;
    var pos: usize = 1;

    // Length as varint
    pos += writeVarint(data.len, buf[pos..]);

    // String data
    @memcpy(buf[pos .. pos + data.len], data);
    pos += data.len;

    return pos;
}

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

/// Output format enum (from conformance.proto WireFormat)
const WireFormat = enum(i32) {
    UNSPECIFIED = 0,
    PROTOBUF = 1,
    JSON = 2,
    JSPB = 3,
    TEXT_FORMAT = 4,
};

/// Test category enum (from conformance.proto TestCategory)
const TestCategory = enum(i32) {
    UNSPECIFIED_TEST = 0,
    BINARY_TEST = 1,
    JSON_TEST = 2,
    JSON_IGNORE_UNKNOWN_PARSING_TEST = 3,
    JSPB_TEST = 4,
    TEXT_FORMAT_TEST = 5,
};

/// Process a single conformance request and produce a response.
fn runTest(request: ConformanceRequest, response_buf: []u8, allocator: std.mem.Allocator) usize {
    // Skip unsupported input formats
    const is_protobuf_input = request.payload_case == .protobuf_payload;
    const is_json_input = request.payload_case == .json_payload;

    if (!is_protobuf_input and !is_json_input) {
        return switch (request.payload_case) {
            .text_payload => encodeSkippedResponse("Text format input not supported", response_buf),
            .jspb_payload => encodeSkippedResponse("JSPB input not supported", response_buf),
            .none => encodeErrorResponse("No payload provided in request", response_buf),
            else => encodeSkippedResponse("Unknown input format", response_buf),
        };
    }

    // Check output format
    const output_format: WireFormat = @enumFromInt(request.requested_output_format);
    const is_protobuf_output = output_format == .PROTOBUF or output_format == .UNSPECIFIED;
    const is_json_output = output_format == .JSON;

    if (!is_protobuf_output and !is_json_output) {
        return switch (output_format) {
            .JSPB => encodeSkippedResponse("JSPB output not supported", response_buf),
            .TEXT_FORMAT => encodeSkippedResponse("Text format output not supported", response_buf),
            else => encodeSkippedResponse("Unknown output format", response_buf),
        };
    }

    // Create an arena for the message
    const arena = upb_zig.Arena.init(allocator) catch {
        return encodeErrorResponse("Failed to create arena", response_buf);
    };
    defer arena.deinit();

    // Determine JSON decode options based on test category
    const test_category: TestCategory = @enumFromInt(request.test_category);
    const json_decode_opts = upb_zig.JsonDecodeOptions{
        .ignore_unknown = (test_category == .JSON_IGNORE_UNKNOWN_PARSING_TEST),
    };

    // Process based on message type
    if (std.mem.eql(u8, request.message_type, "protobuf_test_messages.proto3.TestAllTypesProto3")) {
        // Decode
        const msg = if (is_protobuf_input)
            proto3.TestAllTypesProto3.decode(arena, request.payload) catch {
                return encodeParseErrorResponse("Failed to decode TestAllTypesProto3 from protobuf", response_buf);
            }
        else
            proto3.TestAllTypesProto3.decodeJson(arena, request.payload, json_decode_opts) catch {
                return encodeParseErrorResponse("Failed to decode TestAllTypesProto3 from JSON", response_buf);
            };

        // Encode to requested format
        if (is_protobuf_output) {
            const encoded = msg.encode() catch {
                return encodeSerializeErrorResponse("Failed to encode TestAllTypesProto3 to protobuf", response_buf);
            };
            return encodeProtobufResponse(encoded, response_buf);
        } else {
            const encoded = msg.encodeJson(.{}) catch {
                return encodeSerializeErrorResponse("Failed to encode TestAllTypesProto3 to JSON", response_buf);
            };
            return encodeJsonResponse(encoded, response_buf);
        }
    } else if (std.mem.eql(u8, request.message_type, "protobuf_test_messages.proto2.TestAllTypesProto2")) {
        // Decode
        const msg = if (is_protobuf_input)
            proto2.TestAllTypesProto2.decode(arena, request.payload) catch {
                return encodeParseErrorResponse("Failed to decode TestAllTypesProto2 from protobuf", response_buf);
            }
        else
            proto2.TestAllTypesProto2.decodeJson(arena, request.payload, json_decode_opts) catch {
                return encodeParseErrorResponse("Failed to decode TestAllTypesProto2 from JSON", response_buf);
            };

        // Encode to requested format
        if (is_protobuf_output) {
            const encoded = msg.encode() catch {
                return encodeSerializeErrorResponse("Failed to encode TestAllTypesProto2 to protobuf", response_buf);
            };
            return encodeProtobufResponse(encoded, response_buf);
        } else {
            const encoded = msg.encodeJson(.{}) catch {
                return encodeSerializeErrorResponse("Failed to encode TestAllTypesProto2 to JSON", response_buf);
            };
            return encodeJsonResponse(encoded, response_buf);
        }
    } else if (std.mem.eql(u8, request.message_type, "protobuf_test_messages.editions.proto3.TestAllTypesProto3")) {
        // Decode editions proto3
        const msg = if (is_protobuf_input)
            proto3_editions.TestAllTypesProto3.decode(arena, request.payload) catch {
                return encodeParseErrorResponse("Failed to decode TestAllTypesProto3 (editions) from protobuf", response_buf);
            }
        else
            proto3_editions.TestAllTypesProto3.decodeJson(arena, request.payload, json_decode_opts) catch {
                return encodeParseErrorResponse("Failed to decode TestAllTypesProto3 (editions) from JSON", response_buf);
            };

        // Encode to requested format
        if (is_protobuf_output) {
            const encoded = msg.encode() catch {
                return encodeSerializeErrorResponse("Failed to encode TestAllTypesProto3 (editions) to protobuf", response_buf);
            };
            return encodeProtobufResponse(encoded, response_buf);
        } else {
            const encoded = msg.encodeJson(.{}) catch {
                return encodeSerializeErrorResponse("Failed to encode TestAllTypesProto3 (editions) to JSON", response_buf);
            };
            return encodeJsonResponse(encoded, response_buf);
        }
    } else if (std.mem.eql(u8, request.message_type, "protobuf_test_messages.editions.proto2.TestAllTypesProto2")) {
        // Decode editions proto2
        const msg = if (is_protobuf_input)
            proto2_editions.TestAllTypesProto2.decode(arena, request.payload) catch {
                return encodeParseErrorResponse("Failed to decode TestAllTypesProto2 (editions) from protobuf", response_buf);
            }
        else
            proto2_editions.TestAllTypesProto2.decodeJson(arena, request.payload, json_decode_opts) catch {
                return encodeParseErrorResponse("Failed to decode TestAllTypesProto2 (editions) from JSON", response_buf);
            };

        // Encode to requested format
        if (is_protobuf_output) {
            const encoded = msg.encode() catch {
                return encodeSerializeErrorResponse("Failed to encode TestAllTypesProto2 (editions) to protobuf", response_buf);
            };
            return encodeProtobufResponse(encoded, response_buf);
        } else {
            const encoded = msg.encodeJson(.{}) catch {
                return encodeSerializeErrorResponse("Failed to encode TestAllTypesProto2 (editions) to JSON", response_buf);
            };
            return encodeJsonResponse(encoded, response_buf);
        }
    } else {
        return encodeSkippedResponse("Unsupported message type", response_buf);
    }
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

    // Response buffer (generous size for any response message)
    var response_buf: [4096]u8 = undefined;
    var response_len: usize = 0;

    // Parse the ConformanceRequest
    const request = parseConformanceRequest(request_data) catch {
        response_len = encodeErrorResponse("Failed to parse ConformanceRequest", &response_buf);
        var out_len_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &out_len_buf, @intCast(response_len), .little);
        try writeFullyFd(stdout, &out_len_buf);
        try writeFullyFd(stdout, response_buf[0..response_len]);
        return true;
    };

    // Process the request
    response_len = runTest(request, &response_buf, allocator);

    // Write response with length prefix
    var out_len_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &out_len_buf, @intCast(response_len), .little);
    try writeFullyFd(stdout, &out_len_buf);
    try writeFullyFd(stdout, response_buf[0..response_len]);

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
