//! upb_zig: Conformant Protobuf for Zig via upb
//!
//! This library provides typed Zig bindings over Google's upb (micro protobuf)
//! C runtime. upb handles the wire format encoding/decoding while this library
//! provides ergonomic Zig types and memory management.
//!
//! Memory Management:
//! Unlike the default upb which uses malloc, this library uses Zig's allocator
//! interface. All allocations flow through the std.mem.Allocator you provide.

const std = @import("std");

// Import upb C headers
const c = @cImport({
    @cInclude("upb/mem/arena.h");
    @cInclude("upb/mem/alloc.h");
    @cInclude("upb/base/status.h");
    @cInclude("upb/base/string_view.h");
    @cInclude("upb/message/message.h");
    // Note: We don't include upb/message/accessors.h directly because it has
    // inline functions with alignment casts that Zig's cimport doesn't handle.
    // Instead, we use our C wrapper functions from upb_helpers.h.
    @cInclude("upb/mini_table/message.h");
    @cInclude("upb/mini_table/field.h");
    @cInclude("upb/wire/decode.h");
    @cInclude("upb/wire/encode.h");
    // Our C wrapper that provides safe versions of the accessor functions
    @cInclude("upb_helpers.h");
});

// Re-export C types for generated code to use
pub const upb_Arena = c.upb_Arena;
pub const upb_Message = c.upb_Message;
pub const upb_MiniTable = c.upb_MiniTable;
pub const upb_MiniTableField = c.upb_MiniTableField;
pub const upb_StringView = c.upb_StringView;
pub const upb_Status = c.upb_Status;

// Opaque types for reflection API (forward declared in C)
pub const upb_DefPool = c.upb_DefPool;
pub const upb_FileDef = c.upb_FileDef;
pub const upb_MessageDef = c.upb_MessageDef;

/// Wrapper that bridges Zig's std.mem.Allocator to upb's upb_alloc interface.
/// The upb_alloc field must be first so we can use @fieldParentPtr in the callback.
///
/// Note: upb's free() doesn't pass the allocation size, but Zig's allocator needs it.
/// We solve this by prepending each allocation with a size header.
const ZigUpbAlloc = struct {
    upb_alloc: c.upb_alloc,
    zig_allocator: std.mem.Allocator,

    const Self = @This();
    const Header = struct { size: usize };
    const header_size = @sizeOf(Header);

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .upb_alloc = .{ .func = allocFn },
            .zig_allocator = allocator,
        };
    }

    /// The C callback function that upb calls for all allocations.
    /// Implements combined malloc/realloc/free semantics:
    /// - ptr == null, size > 0  → malloc
    /// - ptr != null, size == 0 → free
    /// - ptr != null, size > 0  → realloc
    fn allocFn(alloc: [*c]c.upb_alloc, ptr: ?*anyopaque, oldsize: usize, size: usize, actual_size: [*c]usize) callconv(.c) ?*anyopaque {
        const self: *Self = @alignCast(@fieldParentPtr("upb_alloc", @as(*c.upb_alloc, alloc)));
        _ = oldsize; // upb doesn't reliably pass this, we track it ourselves

        if (size == 0) {
            // Free
            if (ptr) |p| {
                const user_ptr: [*]u8 = @ptrCast(p);
                const header_ptr: [*]u8 = user_ptr - header_size;
                const header: *Header = @ptrCast(@alignCast(header_ptr));
                const total_size = header.size + header_size;
                const slice: [*]align(16) u8 = @ptrCast(@alignCast(header_ptr));
                self.zig_allocator.free(slice[0..total_size]);
            }
            return null;
        }

        if (ptr == null) {
            // Malloc: allocate header + requested size
            const total_size = header_size + size;
            const mem = self.zig_allocator.alignedAlloc(u8, .@"16", total_size) catch return null;
            const header: *Header = @ptrCast(mem.ptr);
            header.size = size;
            if (actual_size != null) actual_size.* = size;
            return mem.ptr + header_size;
        }

        // Realloc
        const user_ptr: [*]u8 = @ptrCast(ptr.?);
        const header_ptr: [*]align(16) u8 = @ptrCast(@alignCast(user_ptr - header_size));
        const header: *Header = @ptrCast(header_ptr);
        const old_total_size = header.size + header_size;
        const new_total_size = size + header_size;

        const new_mem = self.zig_allocator.realloc(header_ptr[0..old_total_size], new_total_size) catch return null;
        const new_header: *Header = @ptrCast(new_mem.ptr);
        new_header.size = size;
        if (actual_size != null) actual_size.* = size;
        return new_mem.ptr + header_size;
    }
};

/// Arena-based memory allocator wrapping upb_Arena.
/// All protobuf messages are allocated from an arena for efficient bulk deallocation.
///
/// Unlike default upb which uses malloc, this arena uses a Zig allocator that you provide.
/// This gives you full control over memory allocation strategy.
pub const Arena = struct {
    ptr: *c.upb_Arena,
    zig_alloc: *ZigUpbAlloc,
    allocator: std.mem.Allocator,

    /// Create a new arena using the provided Zig allocator.
    /// All upb allocations will flow through this allocator.
    pub fn init(allocator: std.mem.Allocator) !Arena {
        // Allocate the ZigUpbAlloc wrapper
        const zig_alloc = allocator.create(ZigUpbAlloc) catch return error.OutOfMemory;
        zig_alloc.* = ZigUpbAlloc.init(allocator);

        // Create upb arena with our custom allocator (no initial block)
        const arena = c.upb_Arena_Init(null, 0, &zig_alloc.upb_alloc);
        if (arena == null) {
            allocator.destroy(zig_alloc);
            return error.OutOfMemory;
        }

        return Arena{
            .ptr = arena.?,
            .zig_alloc = zig_alloc,
            .allocator = allocator,
        };
    }

    /// Free the arena and all allocations made from it.
    pub fn deinit(self: Arena) void {
        c.upb_Arena_Free(self.ptr);
        self.allocator.destroy(self.zig_alloc);
    }

    /// Allocate memory from the arena.
    pub fn alloc(self: Arena, size: usize) ![]u8 {
        const ptr = c.upb_Arena_Malloc(self.ptr, size);
        if (ptr == null) {
            return error.OutOfMemory;
        }
        const byte_ptr: [*]u8 = @ptrCast(ptr.?);
        return byte_ptr[0..size];
    }

    /// Get the underlying upb_Arena pointer for C interop.
    pub fn raw(self: Arena) *c.upb_Arena {
        return self.ptr;
    }
};

/// Status for error reporting, wrapping upb_Status.
pub const Status = struct {
    status: c.upb_Status,

    pub fn init() Status {
        var s: Status = undefined;
        c.upb_Status_Clear(&s.status);
        return s;
    }

    pub fn isOk(self: *const Status) bool {
        return c.upb_Status_IsOk(&self.status);
    }

    pub fn errorMessage(self: *const Status) []const u8 {
        const msg = c.upb_Status_ErrorMessage(&self.status);
        return std.mem.span(msg);
    }

    pub fn raw(self: *Status) *c.upb_Status {
        return &self.status;
    }
};

// ============================================================================
// Definition Pool - for loading descriptors and extracting MiniTables
// ============================================================================

/// DefPool wraps upb_DefPool for managing proto definitions.
/// Used to load serialized FileDescriptorProto and extract MiniTables.
pub const DefPool = struct {
    ptr: *c.upb_DefPool,

    pub fn init() !DefPool {
        const pool = c.upb_zig_DefPool_New();
        if (pool == null) {
            return error.OutOfMemory;
        }
        return DefPool{ .ptr = pool.? };
    }

    pub fn deinit(self: DefPool) void {
        c.upb_zig_DefPool_Free(self.ptr);
    }

    /// Add a serialized FileDescriptorProto to the pool.
    /// This parses the descriptor and makes its messages available.
    /// Silently succeeds if the file is already loaded.
    pub fn addFile(self: DefPool, serialized_descriptor: []const u8) void {
        var status = Status.init();
        _ = c.upb_zig_DefPool_AddFile(
            self.ptr,
            serialized_descriptor.ptr,
            serialized_descriptor.len,
            status.raw(),
        );
        // We don't return errors - file might already be loaded by a dependency
    }

    /// Find a message by fully-qualified name (e.g., "package.MessageName").
    pub fn findMessage(self: DefPool, name: [:0]const u8) ?*const c.upb_MessageDef {
        return c.upb_zig_DefPool_FindMessageByName(self.ptr, name.ptr);
    }
};

// ============================================================================
// Shared DefPool - global singleton for all proto files in the binary
// ============================================================================

var _shared_def_pool: ?DefPool = null;
var _shared_pool_init: bool = false;

/// Get the shared DefPool used by all generated proto files.
/// Creates the pool on first access.
pub fn sharedDefPool() !DefPool {
    if (!_shared_pool_init) {
        _shared_def_pool = try DefPool.init();
        _shared_pool_init = true;
    }
    return _shared_def_pool.?;
}

/// Get the MiniTable for a message definition.
pub fn getMessageMiniTable(msg_def: *const c.upb_MessageDef) *const c.upb_MiniTable {
    return c.upb_zig_MessageDef_MiniTable(msg_def);
}

/// Find a field in a MiniTable by field number.
pub fn findFieldByNumber(mt: *const c.upb_MiniTable, field_number: u32) ?*const c.upb_MiniTableField {
    return c.upb_zig_MiniTable_FindFieldByNumber(mt, field_number);
}

// ============================================================================
// JSON Encoding/Decoding
// ============================================================================

pub const JsonDecodeError = error{JsonDecodeFailed};
pub const JsonEncodeError = error{JsonEncodeFailed};

/// JSON encode options
pub const JsonEncodeOptions = struct {
    emit_defaults: bool = false,
    use_proto_names: bool = false,
    format_enums_as_integers: bool = false,

    fn toInt(self: JsonEncodeOptions) c_int {
        var opts: c_int = 0;
        if (self.emit_defaults) opts |= c.kupb_zig_JsonEncode_EmitDefaults;
        if (self.use_proto_names) opts |= c.kupb_zig_JsonEncode_UseProtoNames;
        if (self.format_enums_as_integers) opts |= c.kupb_zig_JsonEncode_FormatEnumsAsIntegers;
        return opts;
    }
};

/// JSON decode options
pub const JsonDecodeOptions = struct {
    ignore_unknown: bool = false,

    fn toInt(self: JsonDecodeOptions) c_int {
        var opts: c_int = 0;
        if (self.ignore_unknown) opts |= c.kupb_zig_JsonDecode_IgnoreUnknown;
        return opts;
    }
};

/// Decode JSON into a message.
pub fn jsonDecode(
    msg: *c.upb_Message,
    msg_def: *const c.upb_MessageDef,
    json_data: []const u8,
    pool: DefPool,
    arena: Arena,
    options: JsonDecodeOptions,
) JsonDecodeError!void {
    var status = Status.init();
    const ok = c.upb_zig_JsonDecode(
        json_data.ptr,
        json_data.len,
        msg,
        msg_def,
        pool.ptr,
        options.toInt(),
        arena.ptr,
        status.raw(),
    );
    if (!ok) {
        return JsonDecodeError.JsonDecodeFailed;
    }
}

/// Encode a message to JSON.
/// Returns the JSON string allocated from the arena.
pub fn jsonEncode(
    msg: *const c.upb_Message,
    msg_def: *const c.upb_MessageDef,
    pool: DefPool,
    arena: Arena,
    options: JsonEncodeOptions,
) JsonEncodeError![]const u8 {
    var status = Status.init();

    // First call to get required size
    const required_size = c.upb_zig_JsonEncode(
        msg,
        msg_def,
        pool.ptr,
        options.toInt(),
        null,
        0,
        status.raw(),
    );

    // upb_JsonEncode returns (size_t)-1 on error
    // Only check the return value, not the status (status may have warnings)
    const max_size: usize = std.math.maxInt(usize);
    if (required_size == max_size) {
        return JsonEncodeError.JsonEncodeFailed;
    }

    // Allocate buffer from arena (add 1 for null terminator)
    const buf = arena.alloc(required_size + 1) catch return JsonEncodeError.JsonEncodeFailed;

    // Reset status for second call
    status = Status.init();

    // Second call to actually encode
    const written = c.upb_zig_JsonEncode(
        msg,
        msg_def,
        pool.ptr,
        options.toInt(),
        buf.ptr,
        buf.len,
        status.raw(),
    );

    // Check for error on actual encode
    if (written == max_size) {
        return JsonEncodeError.JsonEncodeFailed;
    }

    return buf[0..written];
}

/// Convert a Zig slice to upb_StringView.
pub fn toStringView(slice: []const u8) c.upb_StringView {
    return c.upb_StringView{
        .data = slice.ptr,
        .size = slice.len,
    };
}

/// Convert upb_StringView to a Zig slice.
pub fn fromStringView(sv: c.upb_StringView) []const u8 {
    if (sv.data == null or sv.size == 0) {
        return &[_]u8{};
    }
    return sv.data[0..sv.size];
}

// ============================================================================
// Message Operations - Untyped API
// ============================================================================
// These are thin wrappers over upb's reflective/dynamic API.
// Generated code creates typed facades over these.

/// Create a new message of the given type.
pub fn messageNew(mini_table: *const c.upb_MiniTable, arena: Arena) ?*c.upb_Message {
    return c.upb_Message_New(mini_table, arena.ptr);
}

// --- Scalar Field Getters ---

pub fn getBool(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, default: bool) bool {
    return c.upb_zig_Message_GetBool(msg, field, default);
}

pub fn getInt32(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, default: i32) i32 {
    return c.upb_zig_Message_GetInt32(msg, field, default);
}

pub fn getInt64(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, default: i64) i64 {
    return c.upb_zig_Message_GetInt64(msg, field, default);
}

pub fn getUInt32(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, default: u32) u32 {
    return c.upb_zig_Message_GetUInt32(msg, field, default);
}

pub fn getUInt64(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, default: u64) u64 {
    return c.upb_zig_Message_GetUInt64(msg, field, default);
}

pub fn getFloat(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, default: f32) f32 {
    return c.upb_zig_Message_GetFloat(msg, field, default);
}

pub fn getDouble(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, default: f64) f64 {
    return c.upb_zig_Message_GetDouble(msg, field, default);
}

pub fn getString(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, default: []const u8) []const u8 {
    const sv = c.upb_zig_Message_GetString(msg, field, toStringView(default));
    return fromStringView(sv);
}

// --- Scalar Field Setters ---

pub fn setBool(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: bool) void {
    c.upb_zig_Message_SetBool(msg, field, value);
}

pub fn setInt32(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: i32) void {
    c.upb_zig_Message_SetInt32(msg, field, value);
}

pub fn setInt64(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: i64) void {
    c.upb_zig_Message_SetInt64(msg, field, value);
}

pub fn setUInt32(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: u32) void {
    c.upb_zig_Message_SetUInt32(msg, field, value);
}

pub fn setUInt64(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: u64) void {
    c.upb_zig_Message_SetUInt64(msg, field, value);
}

pub fn setFloat(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: f32) void {
    c.upb_zig_Message_SetFloat(msg, field, value);
}

pub fn setDouble(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: f64) void {
    c.upb_zig_Message_SetDouble(msg, field, value);
}

pub fn setString(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: []const u8) void {
    c.upb_zig_Message_SetString(msg, field, toStringView(value), null);
}

// --- Array (repeated field) Operations ---

/// Get the number of elements in a repeated field.
pub fn getArrayLen(msg: *const c.upb_Message, field: *const c.upb_MiniTableField) usize {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return 0;
    return c.upb_zig_Array_Size(arr);
}

// Array element getters - take (msg, field, index), return the element value.
// Returns default if the array is null.

pub fn arrayGetBool(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) bool {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return false;
    return c.upb_zig_Array_GetBool(arr, index);
}

pub fn arrayGetInt32(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) i32 {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return 0;
    return c.upb_zig_Array_GetInt32(arr, index);
}

pub fn arrayGetInt64(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) i64 {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return 0;
    return c.upb_zig_Array_GetInt64(arr, index);
}

pub fn arrayGetUInt32(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) u32 {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return 0;
    return c.upb_zig_Array_GetUInt32(arr, index);
}

pub fn arrayGetUInt64(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) u64 {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return 0;
    return c.upb_zig_Array_GetUInt64(arr, index);
}

pub fn arrayGetFloat(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) f32 {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return 0.0;
    return c.upb_zig_Array_GetFloat(arr, index);
}

pub fn arrayGetDouble(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) f64 {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return 0.0;
    return c.upb_zig_Array_GetDouble(arr, index);
}

pub fn arrayGetString(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) []const u8 {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return "";
    return fromStringView(c.upb_zig_Array_GetString(arr, index));
}

pub fn arrayGetMessage(msg: *const c.upb_Message, field: *const c.upb_MiniTableField, index: usize) ?*c.upb_Message {
    const arr = c.upb_zig_Message_GetArray(msg, field);
    if (arr == null) return null;
    const sub = c.upb_zig_Array_GetMessage(arr, index);
    if (sub == null) return null;
    return @constCast(sub);
}

// Array element appenders - take (msg, field, value, arena).
// Creates the array if it doesn't exist.

pub fn arrayAppendBool(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: bool, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendBool(arr, value, arena.ptr)) return error.OutOfMemory;
}

pub fn arrayAppendInt32(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: i32, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendInt32(arr, value, arena.ptr)) return error.OutOfMemory;
}

pub fn arrayAppendInt64(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: i64, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendInt64(arr, value, arena.ptr)) return error.OutOfMemory;
}

pub fn arrayAppendUInt32(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: u32, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendUInt32(arr, value, arena.ptr)) return error.OutOfMemory;
}

pub fn arrayAppendUInt64(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: u64, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendUInt64(arr, value, arena.ptr)) return error.OutOfMemory;
}

pub fn arrayAppendFloat(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: f32, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendFloat(arr, value, arena.ptr)) return error.OutOfMemory;
}

pub fn arrayAppendDouble(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: f64, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendDouble(arr, value, arena.ptr)) return error.OutOfMemory;
}

pub fn arrayAppendString(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: []const u8, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendString(arr, toStringView(value), arena.ptr)) return error.OutOfMemory;
}

pub fn arrayAppendMessage(msg: *c.upb_Message, field: *const c.upb_MiniTableField, value: *c.upb_Message, arena: Arena) !void {
    const arr = c.upb_zig_Message_GetOrCreateMutableArray(msg, field, arena.ptr) orelse return error.OutOfMemory;
    if (!c.upb_zig_Array_AppendMessage(arr, value, arena.ptr)) return error.OutOfMemory;
}

// --- Sub-message (nested message) Operations ---

/// Get a sub-message from a message field. Returns null if not set.
pub fn getMessage(msg: *const c.upb_Message, field: *const c.upb_MiniTableField) ?*c.upb_Message {
    const sub = c.upb_zig_Message_GetMessage(msg, field);
    if (sub == null) return null;
    return @constCast(sub);
}

/// Set a sub-message on a message field.
pub fn setMessage(msg: *c.upb_Message, field: *const c.upb_MiniTableField, sub_msg: *c.upb_Message) void {
    c.upb_zig_Message_SetMessage(msg, field, sub_msg);
}

// --- Encode/Decode ---

pub const EncodeError = error{EncodeFailed};
pub const DecodeError = error{DecodeFailed};

/// Encode a message to wire format bytes.
/// Returns a slice allocated from the arena.
pub fn encode(msg: *const c.upb_Message, mini_table: *const c.upb_MiniTable, arena: Arena) EncodeError![]const u8 {
    var size: usize = 0;
    var buf: [*c]u8 = undefined;
    const status = c.upb_Encode(msg, mini_table, 0, arena.ptr, &buf, &size);
    if (status != c.kUpb_EncodeStatus_Ok or buf == null) {
        return EncodeError.EncodeFailed;
    }
    return buf[0..size];
}

/// Decode wire format bytes into a message.
/// The message must already be created via messageNew().
pub fn decode(msg: *c.upb_Message, mini_table: *const c.upb_MiniTable, data: []const u8, arena: Arena) DecodeError!void {
    const status = c.upb_Decode(data.ptr, data.len, msg, mini_table, null, 0, arena.ptr);
    if (status != c.kUpb_DecodeStatus_Ok) {
        return DecodeError.DecodeFailed;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "Arena: create and destroy" {
    const arena = try Arena.init(std.testing.allocator);
    defer arena.deinit();

    // If we got here, arena was created successfully (init() would have returned error otherwise)
    // Just verify the raw pointer accessor works
    _ = arena.raw();
}

test "Arena: allocate memory" {
    const arena = try Arena.init(std.testing.allocator);
    defer arena.deinit();

    const mem = try arena.alloc(64);
    try std.testing.expectEqual(@as(usize, 64), mem.len);

    // Write to memory to verify it's usable
    @memset(mem, 0xAB);
    try std.testing.expectEqual(@as(u8, 0xAB), mem[0]);
    try std.testing.expectEqual(@as(u8, 0xAB), mem[63]);
}

test "Status: create and check" {
    var status = Status.init();
    try std.testing.expect(status.isOk());
}

test "StringView: round-trip conversion" {
    const original = "hello, protobuf!";
    const sv = toStringView(original);
    const back = fromStringView(sv);
    try std.testing.expectEqualStrings(original, back);
}

test "StringView: empty slice" {
    const empty: []const u8 = &[_]u8{};
    const sv = toStringView(empty);
    const back = fromStringView(sv);
    try std.testing.expectEqual(@as(usize, 0), back.len);
}

test "Arena: uses Zig allocator" {
    const arena = try Arena.init(std.testing.allocator);
    defer arena.deinit();

    const mem1 = try arena.alloc(100);
    const mem2 = try arena.alloc(100);

    try std.testing.expect(@intFromPtr(mem1.ptr) != @intFromPtr(mem2.ptr));

    @memset(mem1, 0xAA);
    @memset(mem2, 0xBB);
    try std.testing.expectEqual(@as(u8, 0xAA), mem1[0]);
    try std.testing.expectEqual(@as(u8, 0xBB), mem2[0]);
}

test "Arena: with FixedBufferAllocator" {
    // Test that we can use a stack-based allocator
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const arena = try Arena.init(fba.allocator());
    defer arena.deinit();

    const mem = try arena.alloc(64);
    try std.testing.expectEqual(@as(usize, 64), mem.len);

    // Verify the memory came from our buffer
    const mem_addr = @intFromPtr(mem.ptr);
    const buf_start = @intFromPtr(&buffer);
    const buf_end = buf_start + buffer.len;
    try std.testing.expect(mem_addr >= buf_start and mem_addr < buf_end);
}
