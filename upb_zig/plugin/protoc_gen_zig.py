#!/usr/bin/env python3
"""
protoc-gen-zig: A protoc plugin that generates Zig bindings over upb.

This plugin reads a CodeGeneratorRequest from stdin and writes a
CodeGeneratorResponse to stdout, following the protoc plugin protocol.

Usage:
    protoc --plugin=protoc-gen-zig=./protoc-gen-zig --zig_out=./gen foo.proto
"""

import sys
from google.protobuf.compiler import plugin_pb2 as plugin
from google.protobuf.descriptor_pb2 import FileDescriptorProto

from codegen import generate_file


def main():
    if sys.stdin.isatty():
        print("ERROR!: protoc-gen-zig is a protoc plugin, it is not intended for direct use.", file=sys.stderr)
        print("", file=sys.stderr)
        print("Usage:", file=sys.stderr)
        print("  protoc --plugin=protoc-gen-zig=./protoc-gen-zig \\", file=sys.stderr)
        print("         --zig_out=./gen \\", file=sys.stderr)
        print("         your_file.proto", file=sys.stderr)
        return 1

    # Read the CodeGeneratorRequest from stdin
    request = plugin.CodeGeneratorRequest()
    request.ParseFromString(sys.stdin.buffer.read())

    # Create response
    response = plugin.CodeGeneratorResponse()

    # Indicate we support proto3 optional fields and editions
    response.supported_features = (
        plugin.CodeGeneratorResponse.FEATURE_PROTO3_OPTIONAL |
        plugin.CodeGeneratorResponse.FEATURE_SUPPORTS_EDITIONS
    )

    # Edition range: EDITION_PROTO2 (998) through EDITION_2023 (1000)
    response.minimum_edition = 998   # EDITION_PROTO2
    response.maximum_edition = 1000  # EDITION_2023

    # Process each file that was requested for generation
    # Build a map of all file descriptors for resolving imports
    file_map: dict[str, FileDescriptorProto] = {
        f.name: f for f in request.proto_file
    }

    for file_name in request.file_to_generate:
        if file_name not in file_map:
            response.error = f"File not found in request: {file_name}"
            sys.stdout.buffer.write(response.SerializeToString())
            return 1

        file_desc = file_map[file_name]

        # Generate the output file
        out_file = response.file.add()
        out_file.name = file_name.replace(".proto", ".pb.zig")

        try:
            out_file.content = generate_file(file_desc, file_map)
        except Exception as e:
            response.error = f"Error generating {file_name}: {e}"
            sys.stdout.buffer.write(response.SerializeToString())
            return 1

    # Write the response to stdout
    sys.stdout.buffer.write(response.SerializeToString())
    return 0


if __name__ == "__main__":
    sys.exit(main())
