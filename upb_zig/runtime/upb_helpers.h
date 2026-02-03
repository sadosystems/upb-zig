// upb_helpers.h - C wrappers for upb inline functions
//
// These wrappers exist because upb's inline functions have pointer casts
// that Zig's cimport translates with strict alignment checks.

#ifndef upb_zig_UPB_HELPERS_H_
#define upb_zig_UPB_HELPERS_H_

#include "upb/message/message.h"
#include "upb/mini_table/field.h"
#include "upb/mini_table/message.h"
#include "upb/base/string_view.h"
#include "upb/base/status.h"
#include "upb/mem/arena.h"

#include <stdbool.h>
#include <stdint.h>

// Forward declarations (avoid including headers with problematic inline functions)
typedef struct upb_DefPool upb_DefPool;
typedef struct upb_FileDef upb_FileDef;
typedef struct upb_MessageDef upb_MessageDef;
typedef struct upb_Array upb_Array;

// JSON decode result codes
enum {
    kupb_zig_JsonDecodeResult_Ok = 0,
    kupb_zig_JsonDecodeResult_Error = 2,
};

#ifdef __cplusplus
extern "C" {
#endif

// String/bytes
upb_StringView upb_zig_Message_GetString(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    upb_StringView default_val);

void upb_zig_Message_SetString(
    upb_Message* msg,
    const upb_MiniTableField* field,
    upb_StringView value,
    upb_Arena* arena);

// Scalars - getters
bool upb_zig_Message_GetBool(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    bool default_val);

int32_t upb_zig_Message_GetInt32(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    int32_t default_val);

int64_t upb_zig_Message_GetInt64(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    int64_t default_val);

uint32_t upb_zig_Message_GetUInt32(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    uint32_t default_val);

uint64_t upb_zig_Message_GetUInt64(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    uint64_t default_val);

float upb_zig_Message_GetFloat(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    float default_val);

double upb_zig_Message_GetDouble(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    double default_val);

// Scalars - setters
void upb_zig_Message_SetBool(
    upb_Message* msg,
    const upb_MiniTableField* field,
    bool value);

void upb_zig_Message_SetInt32(
    upb_Message* msg,
    const upb_MiniTableField* field,
    int32_t value);

void upb_zig_Message_SetInt64(
    upb_Message* msg,
    const upb_MiniTableField* field,
    int64_t value);

void upb_zig_Message_SetUInt32(
    upb_Message* msg,
    const upb_MiniTableField* field,
    uint32_t value);

void upb_zig_Message_SetUInt64(
    upb_Message* msg,
    const upb_MiniTableField* field,
    uint64_t value);

void upb_zig_Message_SetFloat(
    upb_Message* msg,
    const upb_MiniTableField* field,
    float value);

void upb_zig_Message_SetDouble(
    upb_Message* msg,
    const upb_MiniTableField* field,
    double value);

// ============================================================================
// Array (repeated field) operations
// ============================================================================

// Get array from message (read-only, may return NULL)
const upb_Array* upb_zig_Message_GetArray(
    const upb_Message* msg,
    const upb_MiniTableField* field);

// Get or create mutable array (for appending elements)
upb_Array* upb_zig_Message_GetOrCreateMutableArray(
    upb_Message* msg,
    const upb_MiniTableField* field,
    upb_Arena* arena);

// Get array size
size_t upb_zig_Array_Size(const upb_Array* arr);

// Type-specific array element getters
bool upb_zig_Array_GetBool(const upb_Array* arr, size_t index);
int32_t upb_zig_Array_GetInt32(const upb_Array* arr, size_t index);
int64_t upb_zig_Array_GetInt64(const upb_Array* arr, size_t index);
uint32_t upb_zig_Array_GetUInt32(const upb_Array* arr, size_t index);
uint64_t upb_zig_Array_GetUInt64(const upb_Array* arr, size_t index);
float upb_zig_Array_GetFloat(const upb_Array* arr, size_t index);
double upb_zig_Array_GetDouble(const upb_Array* arr, size_t index);
upb_StringView upb_zig_Array_GetString(const upb_Array* arr, size_t index);
const upb_Message* upb_zig_Array_GetMessage(const upb_Array* arr, size_t index);

// Type-specific array element appenders (return false on allocation failure)
bool upb_zig_Array_AppendBool(upb_Array* arr, bool val, upb_Arena* arena);
bool upb_zig_Array_AppendInt32(upb_Array* arr, int32_t val, upb_Arena* arena);
bool upb_zig_Array_AppendInt64(upb_Array* arr, int64_t val, upb_Arena* arena);
bool upb_zig_Array_AppendUInt32(upb_Array* arr, uint32_t val, upb_Arena* arena);
bool upb_zig_Array_AppendUInt64(upb_Array* arr, uint64_t val, upb_Arena* arena);
bool upb_zig_Array_AppendFloat(upb_Array* arr, float val, upb_Arena* arena);
bool upb_zig_Array_AppendDouble(upb_Array* arr, double val, upb_Arena* arena);
bool upb_zig_Array_AppendString(upb_Array* arr, upb_StringView val, upb_Arena* arena);
bool upb_zig_Array_AppendMessage(upb_Array* arr, const upb_Message* val, upb_Arena* arena);

// ============================================================================
// Field presence check
// ============================================================================

// Check if a field is set (works for oneofs, optional fields, etc.)
bool upb_zig_Message_HasField(
    const upb_Message* msg,
    const upb_MiniTableField* field);

// ============================================================================
// Sub-message (nested message) operations
// ============================================================================

// Get sub-message from a message field (returns NULL if not set)
const upb_Message* upb_zig_Message_GetMessage(
    const upb_Message* msg,
    const upb_MiniTableField* field);

// Set sub-message on a message field
void upb_zig_Message_SetMessage(
    upb_Message* msg,
    const upb_MiniTableField* field,
    upb_Message* sub_msg);

// ============================================================================
// Reflection API wrappers - for loading MiniTables from serialized descriptors
// ============================================================================

// Create a new DefPool for loading descriptors
upb_DefPool* upb_zig_DefPool_New(void);

// Free a DefPool
void upb_zig_DefPool_Free(upb_DefPool* pool);

// Add a serialized FileDescriptorProto to the pool.
// Returns the FileDef on success, NULL on failure.
// Check status for error message on failure.
const upb_FileDef* upb_zig_DefPool_AddFile(
    upb_DefPool* pool,
    const uint8_t* serialized_descriptor,
    size_t len,
    upb_Status* status);

// Find a message definition by fully-qualified name (e.g., "package.MessageName")
const upb_MessageDef* upb_zig_DefPool_FindMessageByName(
    const upb_DefPool* pool,
    const char* name);

// Get the MiniTable for a message definition
const upb_MiniTable* upb_zig_MessageDef_MiniTable(const upb_MessageDef* m);

// Get the MiniTableField for a field in a message by field number
const upb_MiniTableField* upb_zig_MiniTable_FindFieldByNumber(
    const upb_MiniTable* mt,
    uint32_t field_number);

// ============================================================================
// JSON API wrappers
// ============================================================================

// Decode JSON into a message.
// Returns true on success, false on error.
// Check status for error message on failure.
bool upb_zig_JsonDecode(
    const char* buf,
    size_t size,
    upb_Message* msg,
    const upb_MessageDef* m,
    const upb_DefPool* symtab,
    int options,
    upb_Arena* arena,
    upb_Status* status);

// Encode a message to JSON.
// Returns the output size (excluding NULL terminator).
// If return value >= size, output was truncated.
size_t upb_zig_JsonEncode(
    const upb_Message* msg,
    const upb_MessageDef* m,
    const upb_DefPool* ext_pool,
    int options,
    char* buf,
    size_t size,
    upb_Status* status);

// JSON encode options
enum {
    kupb_zig_JsonEncode_EmitDefaults = 1 << 0,
    kupb_zig_JsonEncode_UseProtoNames = 1 << 1,
    kupb_zig_JsonEncode_FormatEnumsAsIntegers = 1 << 2,
};

// JSON decode options
enum {
    kupb_zig_JsonDecode_IgnoreUnknown = 1,
};

#ifdef __cplusplus
}
#endif

#endif  // upb_zig_UPB_HELPERS_H_
