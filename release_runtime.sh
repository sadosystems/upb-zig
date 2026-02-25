bazel build //upb_zig/runtime:runtime_tarball && 
gh release create  v0.0.0 bazel-bin/upb_zig/runtime/upb-zig-runtime.tar.gz
