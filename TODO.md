Add `zig-protobuf` as external Bazel dependency (get it added to BCR or rules_zig)
Write conformance testee using zig-protobuf's API
update conformance suite table gen to and compare results across both APIs 
README.md with quickstart guide
API documentation for runtime library
Example usage in a Zig project
Document `zig_proto_library` macro usage
publish the python script on pypi (and add to path)
rewrite the plugin (just code gen part not the runtime) in zig
cross compile binary to all platforms and distribute those with gh releases so you don't need to use python / pip
maybe do some profiling to see how much worse this implementation performs vs protobuf-zig