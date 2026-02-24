<p align="center">
  <img src=".github/upb-Zig-logo.png" width="300">
</p>

⚠️ UNDER CONSTRUCTION ⚠️

# μpb-Zig: Zig support for protocol buffers
This project hosts a Zig implementation of [protocol buffers](https://protobuf.dev/) which is a language-neutral mechanism for serializing structured data. It includes code gen that produces Zig bindings from `.proto` schemas and a runtime library to handle serialization. See the [protocol buffer developer guide](https://protobuf.dev/overview/) for more information about protocol buffers themselves. The implementation is backed by upb.

This project is comprised of two components:

- Code generator: The `upb_zig/plugin` folder contains [protoc-gen-zig](https://pypi.org/project/protoc-gen-zig/) a compiler plugin to protoc, the protocol buffer compiler. It augments the protoc compiler so that it knows how to generate Zig specific code for a given .proto file.

- Runtime library: The `upb_zig/runtime` folder contains a Zig module that forms the runtime implementation of protobufs in Zig. This provides the set of types and functions that define what a message is and functionality to serialize messages in various formats (e.g., wire, JSON, and text).

upb-zig is the only Zig protobuf library that passes [all the protobuf conformance tests](https://github.com/sadosystems/upb-zig/tree/master?tab=readme-ov-file#protobuf-conformance-tests). That's actually [_NOT_ as impressive as it sounds](https://github.com/sadosystems/upb-zig/tree/master?tab=readme-ov-file#how-it-works)! Despite that seemingly impressive test coverage, this library is NOT ready for production use. It has API and performance issues which may or may not ever be worked out.

Also holy bloat this project will not appeal to your Zig-like sensibilities. do not be mislead by the "μ" in upb there is nothing micro about this dependency. The code generator is distributed as either a Bazel rule or a Python exectuable on Pypi so you will need a Python interpreter to generate code and the runtime is mostly C not Zig.

You should probably use [zig-protobuf](https://github.com/Arwalk/zig-protobuf) instead unless you absolutely need full conformance.

Also if you are a Bazel user, I have some rules for you! 

## Installation

### Code Generator
The Code generator is a Python script, so you need to have python installed (with pip) in order to install it.
Install the protoc plugin via PyPI.
```shell
pip install protoc-gen-zig
```
#### Runtime Library
Add `upb` to your `build.zig.zon`.
```shell
zig fetch --save "git+https://github.com/sadosystems/upb-zig#master"
```
To use the `upb` module add the dependency to your build.zig's build function before b.installArtifact(exe).
```shell
pub fn build(b: *std.Build) !void {
    // first create a build for the dependency
    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });

    // and lastly use the dependency as a module
    exe.root_module.addImport("protobuf", protobuf_dep.module("protobuf"));
}
```

####  Bazel
```Python
bazel_dep(name = "upb-zig", version = "1.0.0")
```

## Use
You can either use this library as a Bazel module, or you can import it in you Bazel build script, I have created example repos demonstrating both integration approaches.

[Example repo using build.zig](https://github.com/sadosystems/upb-zig-minimal-example)
[Example repo using MODULE.bazel](TODO)

## Why?
Why make this when [zig-protobuf](https://github.com/Arwalk/zig-protobuf) and [gremlin.zig](https://github.com/norma-core/gremlin.zig) exist?

I was working on a project in Zig that required the use of protobuf. On a different project, in a different language I once reached for a protobuf implementation on github and just assumed it would be conformant, way later in development I tracked down a highly annoying bug that was caused by the fact that the library I was using was not in fact conformant. On that day I vowed to never again use a non-conformant implementation of protobuf.

So when I found [zig-protobuf](https://github.com/Arwalk/zig-protobuf) the first thing I looked for was conformance tests, then to my dismay I found [this issue](https://github.com/Arwalk/zig-protobuf/issues/27). Long-story-short zig-protobuf is not tested against the conformance test suite provided by Google.

So I wired them up. [Here is the result](https://github.com/sadosystems/upb-zig?tab=readme-ov-file#protobuf-conformance-tests).

I was depressed when I discovered zig-protobuf is not conformant. I was really starting to hate protobuf and I did not want to write my own implementation. The core may be [simple enough](https://protobuf.dev/programming-guides/encoding/) but tracking down every little edge case is a nightmare.

in particular I did not want to handle:
- [proto3 vs proto2 vs editions](https://protobuf.dev/editions/overview/)
- [JSON enc/dec](https://protobuf.dev/programming-guides/json/) especially with [well-known types](https://protobuf.dev/reference/protobuf/google.protobuf/#any)
- oneofs, unknown fields, extensions, etc.
- bootstrapping (protoc plugins are authored as executables that take serialized Descriptors, which are serialized using... protobuf!)
- many edge cases I don't even know about

but then I had an idea...

## How it Works
An implementation so dumb that it wraps all the way around to being kinda smart. 
- A. Use a language that already has protobuf support for the code gen so I can avoid the bootstrapping stuff.
- B. Don't write a runtime in Zig at all, just wrap an existing runtime.  

The code generator is written in Python using mako templates. The runtime that the generated code calls into is just a wrapper around the C [upb](https://github.com/protocolbuffers/protobuf/tree/main/upb) protobuf runtime (hence the name of this project **upb**-zig) 

The actual encode decode logic is in the C runtime and it is fully conformant[*](https://github.com/protocolbuffers/protobuf/blob/main/upb/conformance/conformance_upb_failures.txt) for free. The only Zig parts are a thin wrapper around upb and the typed facade into that wrapper which is generated by the Python code.  

This is sort of silly (really silly) and un-Zig-like. The upb runtime is designed to be wrapped by scripting languages (it's the heart of the Python Ruby and PHP implementations). As far as I know there are no mainstream protobuf implementations for a systems language that wrap upb.


BUT this was very easy to hack together quickly, so I did it.

As a bonus this could also enable a "reflective" / dynamic API. That could be useful for making tools with Zig that load proto descriptorPools at runtime.

Since protobuf implementations have a bootstrapping problem a throwaway implementation can have some value. This could be used to help bootstrap an all-Zig version. Maybe it could be useful to the [zig-protobuf](https://github.com/Arwalk/zig-protobuf) project? 

Coda: As it turns out, there kinda is a "mainstream protobuf implementations for a systems language that wrap upb". The [official Rust implementation](https://protobuf.dev/reference/rust/rust-design-decisions/) uses a upb "kernel" in its public release. Most people in the Rust ecosystem use `protst!` for protobuf support, so I am not sure if this counts as mainstream.

## Protobuf Conformance Tests

### Implementations
The current implementations being tested are:

- zig-protobuf: https://github.com/Arwalk/zig-protobuf
- upb-zig: https://github.com/sadosystems/upb-zig

### Results
<!-- BEGIN CONFORMANCE TABLE -->
Category|upb-zig|zig-protobuf
---------|---------|---------
Overall | ![5591_5615](.github/badges/5591_5615.svg) | ![813_5615](.github/badges/813_5615.svg)
Required | ![4303_4315](.github/badges/4303_4315.svg) | ![579_4315](.github/badges/579_4315.svg)
Required Proto2 | ![993_995](.github/badges/993_995.svg) | ![0_995](.github/badges/0_995.svg)
Required Proto3 | ![1151_1155](.github/badges/1151_1155.svg) | ![579_1155](.github/badges/579_1155.svg)
Required Editions_Proto2 | ![990_992](.github/badges/990_992.svg) | ![0_992](.github/badges/0_992.svg)
Required Editions_Proto3 | ![1151_1155](.github/badges/1151_1155.svg) | ![0_1155](.github/badges/0_1155.svg)
Recommended | ![1288_1300](.github/badges/1288_1300.svg) | ![234_1300](.github/badges/234_1300.svg)
Recommended Proto2 | ![315_318](.github/badges/315_318.svg) | ![0_318](.github/badges/0_318.svg)
Recommended Proto3 | ![330_333](.github/badges/330_333.svg) | ![234_333](.github/badges/234_333.svg)
Recommended Editions_Proto2 | ![313_316](.github/badges/313_316.svg) | ![0_316](.github/badges/0_316.svg)
Recommended Editions_Proto3 | ![330_333](.github/badges/330_333.svg) | ![0_333](.github/badges/0_333.svg)

<!-- END CONFORMANCE TABLE -->

Here is a more fine grained test by test breakdown: [todo add this]

#### Running the Tests
To run the conformance test suite for upb-zig run: 
```shell
bazel build //upb_zig/conformance:upb_fails
```
This will produce a .txt file enumerating the failing tests.

Same deal for zig-protobuf
```shell
bazel build //zig_protobuf/conformance:protobuf_zig_fails
```

To regenerate the conformance result comparison table, run the following command 
```shell
bazel build //conformance:update_report
```
This script will actually update the files in the source tree.

interesting issue https://github.com/Arwalk/zig-protobuf/issues/144
I want to comment on this directly but I am not sure how.
