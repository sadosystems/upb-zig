// upb_helpers.c - C wrappers for upb inline functions
//
// These wrappers exist because upb's inline functions have pointer casts
// that Zig's cimport translates with strict alignment checks. By wrapping
// them in regular C functions, the C compiler handles the casts and Zig
// just sees normal function calls.

#include "upb/message/accessors.h"
#include "upb/message/array.h"
#include "upb/base/string_view.h"
#include "upb/reflection/def.h"
#include "upb/reflection/descriptor_bootstrap.h"
#include "upb/mini_table/message.h"
#include "upb/json/decode.h"
#include "upb/json/encode.h"

// String/bytes getters and setters
upb_StringView upb_zig_Message_GetString(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    upb_StringView default_val) {
  return upb_Message_GetString(msg, field, default_val);
}

void upb_zig_Message_SetString(
    upb_Message* msg,
    const upb_MiniTableField* field,
    upb_StringView value,
    upb_Arena* arena) {
  upb_Message_SetBaseFieldString(msg, field, value);
  (void)arena; // Arena not needed for SetBaseFieldString
}

// Scalar getters - wrap in case they have similar issues
bool upb_zig_Message_GetBool(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    bool default_val) {
  return upb_Message_GetBool(msg, field, default_val);
}

int32_t upb_zig_Message_GetInt32(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    int32_t default_val) {
  return upb_Message_GetInt32(msg, field, default_val);
}

int64_t upb_zig_Message_GetInt64(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    int64_t default_val) {
  return upb_Message_GetInt64(msg, field, default_val);
}

uint32_t upb_zig_Message_GetUInt32(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    uint32_t default_val) {
  return upb_Message_GetUInt32(msg, field, default_val);
}

uint64_t upb_zig_Message_GetUInt64(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    uint64_t default_val) {
  return upb_Message_GetUInt64(msg, field, default_val);
}

float upb_zig_Message_GetFloat(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    float default_val) {
  return upb_Message_GetFloat(msg, field, default_val);
}

double upb_zig_Message_GetDouble(
    const upb_Message* msg,
    const upb_MiniTableField* field,
    double default_val) {
  return upb_Message_GetDouble(msg, field, default_val);
}

// Scalar setters
void upb_zig_Message_SetBool(
    upb_Message* msg,
    const upb_MiniTableField* field,
    bool value) {
  upb_Message_SetBaseFieldBool(msg, field, value);
}

void upb_zig_Message_SetInt32(
    upb_Message* msg,
    const upb_MiniTableField* field,
    int32_t value) {
  upb_Message_SetBaseFieldInt32(msg, field, value);
}

void upb_zig_Message_SetInt64(
    upb_Message* msg,
    const upb_MiniTableField* field,
    int64_t value) {
  upb_Message_SetBaseFieldInt64(msg, field, value);
}

void upb_zig_Message_SetUInt32(
    upb_Message* msg,
    const upb_MiniTableField* field,
    uint32_t value) {
  upb_Message_SetBaseFieldUInt32(msg, field, value);
}

void upb_zig_Message_SetUInt64(
    upb_Message* msg,
    const upb_MiniTableField* field,
    uint64_t value) {
  upb_Message_SetBaseFieldUInt64(msg, field, value);
}

void upb_zig_Message_SetFloat(
    upb_Message* msg,
    const upb_MiniTableField* field,
    float value) {
  upb_Message_SetBaseFieldFloat(msg, field, value);
}

void upb_zig_Message_SetDouble(
    upb_Message* msg,
    const upb_MiniTableField* field,
    double value) {
  upb_Message_SetBaseFieldDouble(msg, field, value);
}

// ============================================================================
// Array (repeated field) operations
// ============================================================================

const upb_Array* upb_zig_Message_GetArray(
    const upb_Message* msg,
    const upb_MiniTableField* field) {
  return upb_Message_GetArray(msg, field);
}

upb_Array* upb_zig_Message_GetOrCreateMutableArray(
    upb_Message* msg,
    const upb_MiniTableField* field,
    upb_Arena* arena) {
  return upb_Message_GetOrCreateMutableArray(msg, field, arena);
}

size_t upb_zig_Array_Size(const upb_Array* arr) {
  return upb_Array_Size(arr);
}

// Type-specific getters
bool upb_zig_Array_GetBool(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).bool_val;
}

int32_t upb_zig_Array_GetInt32(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).int32_val;
}

int64_t upb_zig_Array_GetInt64(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).int64_val;
}

uint32_t upb_zig_Array_GetUInt32(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).uint32_val;
}

uint64_t upb_zig_Array_GetUInt64(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).uint64_val;
}

float upb_zig_Array_GetFloat(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).float_val;
}

double upb_zig_Array_GetDouble(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).double_val;
}

upb_StringView upb_zig_Array_GetString(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).str_val;
}

const upb_Message* upb_zig_Array_GetMessage(const upb_Array* arr, size_t index) {
  return upb_Array_Get(arr, index).msg_val;
}

// Type-specific appenders
bool upb_zig_Array_AppendBool(upb_Array* arr, bool val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.bool_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

bool upb_zig_Array_AppendInt32(upb_Array* arr, int32_t val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.int32_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

bool upb_zig_Array_AppendInt64(upb_Array* arr, int64_t val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.int64_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

bool upb_zig_Array_AppendUInt32(upb_Array* arr, uint32_t val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.uint32_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

bool upb_zig_Array_AppendUInt64(upb_Array* arr, uint64_t val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.uint64_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

bool upb_zig_Array_AppendFloat(upb_Array* arr, float val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.float_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

bool upb_zig_Array_AppendDouble(upb_Array* arr, double val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.double_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

bool upb_zig_Array_AppendString(upb_Array* arr, upb_StringView val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.str_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

bool upb_zig_Array_AppendMessage(upb_Array* arr, const upb_Message* val, upb_Arena* arena) {
  upb_MessageValue msgval;
  msgval.msg_val = val;
  return upb_Array_Append(arr, msgval, arena);
}

// ============================================================================
// Field presence check
// ============================================================================

bool upb_zig_Message_HasField(
    const upb_Message* msg,
    const upb_MiniTableField* field) {
  return upb_Message_HasBaseField(msg, field);
}

// ============================================================================
// Sub-message (nested message) operations
// ============================================================================

const upb_Message* upb_zig_Message_GetMessage(
    const upb_Message* msg,
    const upb_MiniTableField* field) {
  return upb_Message_GetMessage(msg, field);
}

void upb_zig_Message_SetMessage(
    upb_Message* msg,
    const upb_MiniTableField* field,
    upb_Message* sub_msg) {
  upb_Message_SetBaseFieldMessage(msg, field, sub_msg);
}

// ============================================================================
// Reflection API wrappers
// ============================================================================

upb_DefPool* upb_zig_DefPool_New(void) {
  return upb_DefPool_New();
}

void upb_zig_DefPool_Free(upb_DefPool* pool) {
  upb_DefPool_Free(pool);
}

const upb_FileDef* upb_zig_DefPool_AddFile(
    upb_DefPool* pool,
    const uint8_t* serialized_descriptor,
    size_t len,
    upb_Status* status) {
  // Create a temporary arena for parsing the FileDescriptorProto
  upb_Arena* arena = upb_Arena_New();
  if (!arena) {
    if (status) upb_Status_SetErrorMessage(status, "Failed to allocate arena");
    return NULL;
  }

  // Parse the serialized FileDescriptorProto
  google_protobuf_FileDescriptorProto* file_proto =
      google_protobuf_FileDescriptorProto_parse(
          (const char*)serialized_descriptor, len, arena);
  if (!file_proto) {
    upb_Arena_Free(arena);
    if (status) upb_Status_SetErrorMessage(status, "Failed to parse FileDescriptorProto");
    return NULL;
  }

  // Add the file to the DefPool
  const upb_FileDef* file_def = upb_DefPool_AddFile(pool, file_proto, status);

  // Free the temporary arena (file_def is owned by the pool)
  upb_Arena_Free(arena);

  return file_def;
}

const upb_MessageDef* upb_zig_DefPool_FindMessageByName(
    const upb_DefPool* pool,
    const char* name) {
  return upb_DefPool_FindMessageByName(pool, name);
}

const upb_MiniTable* upb_zig_MessageDef_MiniTable(const upb_MessageDef* m) {
  return upb_MessageDef_MiniTable(m);
}

const upb_MiniTableField* upb_zig_MiniTable_FindFieldByNumber(
    const upb_MiniTable* mt,
    uint32_t field_number) {
  return upb_MiniTable_FindFieldByNumber(mt, field_number);
}

// ============================================================================
// JSON API wrappers
// ============================================================================

bool upb_zig_JsonDecode(
    const char* buf,
    size_t size,
    upb_Message* msg,
    const upb_MessageDef* m,
    const upb_DefPool* symtab,
    int options,
    upb_Arena* arena,
    upb_Status* status) {
  return upb_JsonDecode(buf, size, msg, m, symtab, options, arena, status);
}

size_t upb_zig_JsonEncode(
    const upb_Message* msg,
    const upb_MessageDef* m,
    const upb_DefPool* ext_pool,
    int options,
    char* buf,
    size_t size,
    upb_Status* status) {
  return upb_JsonEncode(msg, m, ext_pool, options, buf, size, status);
}
