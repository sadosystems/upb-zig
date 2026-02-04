bazel build protoc_gen_zig_wheel
WHEEL=$(bazel cquery protoc_gen_zig_wheel --output=files)
twine upload $WHEEL