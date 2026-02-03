Add `zig-protobuf` as external Bazel dependency
Write conformance testee using zig-protobuf's API
Run conformance suite and capture results
Parse conformance test output for both implementations
[DONE] Generate markdown table with:
[DONE] Automate report generation as Bazel target
README.md with quickstart guide
API documentation for runtime library
Example usage in a Zig project
Document `zig_proto_library` macro usage
Cross-compilation examples (Windows target)
publish the python script on pypi (and add to path)
rewrite the plugin (just code gen part not the runtime) in zig
cross compile binary to all platforms and distribute those with gh releases so you don't need to use python / pip
maybe do some profiling to see how much worse this implementation performs