//! Conformance test harness for zig-protobuf.
//!
//! Implements the conformance testing protocol defined in conformance.proto.
//! Reads ConformanceRequest messages from stdin and writes ConformanceResponse
//! messages to stdout using the length-prefixed wire protocol.

const std = @import("std");
const protobuf = @import("protobuf");
const pb = @import("conformance_zig_protos");

const ConformanceRequest = pb.conformance.ConformanceRequest;
const ConformanceResponse = pb.conformance.ConformanceResponse;
const TestAllTypesProto3 = pb.proto3.TestAllTypesProto3;

/// Read exactly `len` bytes from stdin.
fn readFully(fd: std.posix.fd_t, buf: []u8) !void {
    var total: usize = 0;
    while (total < buf.len) {
        const n = std.posix.read(fd, buf[total..]) catch |err| return err;
        if (n == 0) return error.EndOfStream;
        total += n;
    }
}

/// Write all bytes to stdout.
fn writeFully(fd: std.posix.fd_t, buf: []const u8) !void {
    var total: usize = 0;
    while (total < buf.len) {
        const n = std.posix.write(fd, buf[total..]) catch |err| return err;
        total += n;
    }
}

/// Encode a protobuf message to bytes using an allocating writer.
fn encodeToBytes(allocator: std.mem.Allocator, msg: anytype) ![]const u8 {
    var w: std.Io.Writer.Allocating = .init(allocator);
    errdefer w.deinit();
    try msg.encode(&w.writer, allocator);
    return w.written();
}

/// Decode a test message from protobuf binary, re-encode to protobuf binary.
fn roundTripProtobuf(
    comptime MsgType: type,
    allocator: std.mem.Allocator,
    payload: []const u8,
) ![]const u8 {
    var reader: std.Io.Reader = .fixed(payload);
    var msg = try MsgType.decode(&reader, allocator);
    defer msg.deinit(allocator);
    return encodeToBytes(allocator, msg);
}

/// Process a single conformance request and produce a response.
fn runTest(allocator: std.mem.Allocator, req: ConformanceRequest) ConformanceResponse {
    // Check payload type
    const payload_union = req.payload orelse
        return makeResponse(.{ .runtime_error = "No payload in request" });

    const is_protobuf_input = payload_union == .protobuf_payload;
    const is_json_input = payload_union == .json_payload;

    if (!is_protobuf_input and !is_json_input) {
        return makeResponse(.{ .protobuf_payload = "JUNK" });
    }

    // Check output format
    const is_protobuf_output = req.requested_output_format == .PROTOBUF or
        req.requested_output_format == .UNSPECIFIED;
    const is_json_output = req.requested_output_format == .JSON;

    if (!is_protobuf_output and !is_json_output) {
        return makeResponse(.{ .protobuf_payload = "JUNK" });
    }

    // Route by message type
    if (std.mem.eql(u8, req.message_type, "protobuf_test_messages.proto3.TestAllTypesProto3")) {
        return doRoundTrip(TestAllTypesProto3, allocator, payload_union, is_protobuf_input, is_protobuf_output);
    } else {
        return makeResponse(.{ .protobuf_payload = "JUNK" });
    }
}

/// Decode a test message, re-encode it in the requested format.
fn doRoundTrip(
    comptime MsgType: type,
    allocator: std.mem.Allocator,
    payload_union: ConformanceRequest.payload_union,
    is_protobuf_input: bool,
    is_protobuf_output: bool,
) ConformanceResponse {
    if (is_protobuf_input) {
        const payload = payload_union.protobuf_payload;

        if (is_protobuf_output) {
            const encoded = roundTripProtobuf(MsgType, allocator, payload) catch
                return makeResponse(.{ .parse_error = "Failed to decode protobuf" });
            return makeResponse(.{ .protobuf_payload = encoded });
        } else {
            // protobuf -> json
            var reader: std.Io.Reader = .fixed(payload);
            var msg = MsgType.decode(&reader, allocator) catch
                return makeResponse(.{ .parse_error = "Failed to decode protobuf" });
            defer msg.deinit(allocator);
            const json = msg.jsonEncode(.{}, allocator) catch
                return makeResponse(.{ .serialize_error = "Failed to encode JSON" });
            return makeResponse(.{ .json_payload = json });
        }
    } else {
        // JSON input
        const json_payload = payload_union.json_payload;

        const parsed = MsgType.jsonDecode(json_payload, .{}, allocator) catch
            return makeResponse(.{ .parse_error = "Failed to decode JSON" });
        defer parsed.deinit();
        const msg = parsed.value;

        if (is_protobuf_output) {
            const encoded = encodeToBytes(allocator, msg) catch
                return makeResponse(.{ .serialize_error = "Failed to encode protobuf" });
            return makeResponse(.{ .protobuf_payload = encoded });
        } else {
            const json = msg.jsonEncode(.{}, allocator) catch
                return makeResponse(.{ .serialize_error = "Failed to encode JSON" });
            return makeResponse(.{ .json_payload = json });
        }
    }
}

fn makeResponse(result: ConformanceResponse.result_union) ConformanceResponse {
    return .{ .result = result };
}

/// Serve a single conformance request. Returns false on EOF.
fn serveConformanceRequest(allocator: std.mem.Allocator) !bool {
    const stdin = std.posix.STDIN_FILENO;
    const stdout = std.posix.STDOUT_FILENO;

    // Read 4-byte little-endian length prefix
    var len_buf: [4]u8 = undefined;
    readFully(stdin, &len_buf) catch |err| {
        if (err == error.EndOfStream) return false;
        return err;
    };
    const in_len = std.mem.readInt(u32, &len_buf, .little);
    if (in_len == 0) return false;

    // Read serialized request
    const request_data = try allocator.alloc(u8, in_len);
    defer allocator.free(request_data);
    try readFully(stdin, request_data);

    // Decode ConformanceRequest
    var reader: std.Io.Reader = .fixed(request_data);
    var request = ConformanceRequest.decode(&reader, allocator) catch {
        // Can't even parse the request -- send runtime error
        const resp = makeResponse(.{ .runtime_error = "Failed to parse ConformanceRequest" });
        try writeResponse(stdout, allocator, resp);
        return true;
    };
    defer request.deinit(allocator);

    // Process request
    const response = runTest(allocator, request);

    // Encode and write response
    try writeResponse(stdout, allocator, response);
    return true;
}

fn writeResponse(fd: std.posix.fd_t, allocator: std.mem.Allocator, response: ConformanceResponse) !void {
    var w: std.Io.Writer.Allocating = .init(allocator);
    defer w.deinit();

    response.encode(&w.writer, allocator) catch {
        // Last resort: empty response
        var out_len_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &out_len_buf, 0, .little);
        try writeFully(fd, &out_len_buf);
        return;
    };
    const response_bytes = w.written();

    var out_len_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &out_len_buf, @intCast(response_bytes.len), .little);
    try writeFully(fd, &out_len_buf);
    try writeFully(fd, response_bytes);
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
        if (!should_continue) break;
        total_runs += 1;
    }

    std.log.info("conformance-zig-protobuf: received EOF after {} tests", .{total_runs});
}
