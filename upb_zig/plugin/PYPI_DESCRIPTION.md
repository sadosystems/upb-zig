# protoc-gen-zig

A protoc plugin that generates Zig bindings for Protocol Buffers, backed by [upb](https://github.com/protocolbuffers/protobuf/tree/main/upb).
`protoc-gen-zig` is part of the [upb-zig](https://github.com/sadosystems/upb-zig)
project. `protoc-gen-zig` is the only Zig Protobuf implementation that passes [ the Protobuf conformance
tests](https://github.com/sadosystems/upb-zig/tree/master?tab=readme-ov-file#protobuf-conformance-tests).

## Installation
Install the [Protobuf compiler](https://protobuf.dev/installation/) first. 
```shell
pip install protoc-gen-zig
```

## Usage

```shell
protoc --zig_out=./gen your_file.proto
```
This assumes protoc-gen-zig has been added to $PATH, otherwise provide the path to protoc-gen-zig.
```shell
protoc --plugin=protoc-gen-zig --zig_out=./gen your_file.proto
```

### How it Works

The code generator is written in Python using Mako templates. It reads protoc's
CodeGeneratorRequest and outputs Zig source files that wrap the [upb](https://github.com/protocolbuffers/protobuf/tree/main/upb) C runtime. The actual encode/decode logic lives in upb, which is fully conformant [*](https://github.com/protocolbuffers/protobuf/blob/main/upb/conformance/conformance_upb_failures.txt.) The generated Zig code is a thin typed facade over that runtime.

[Full runtime library and Bazel integration](https://github.com/sadosystems/upb-zig). 