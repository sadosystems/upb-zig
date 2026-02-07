"""
protobuf conformance testee that systematically fails all tests. It still 
implements the conformance testing protocol (reads ConformanceRequest from 
stdin, write ConformanceResponse to stdout) just to keep the tests moving.
ConformanceResponse is a oneof (semantically similar to a tagged union or
a rust enum) with some error variants (like serialize_error) and some ok 
result variants (like json_payload). The error variants represent unexpected 
failures used for debugging the testee code NOT the protobuf implementation.
so when the testee returns one of these error variants the whole test just 
stops.

That is not the behavior we want. We want the tester to try every test, and 
for every test to fail.     

Wire format wise oneofs are more product type than sum type so you can 
actually set multiple variants of a oneof. My solution is just to return a
ConformanceResponse with json_payload and protobuf_payload both set to junk.
this seems to work pretty well!

I had to make some depressing compromises on import path to keep the 
conformance.proto out of the source tree, hence the runfiles+importlib style
import.
"""
import sys
import struct
from pathlib import Path
import importlib.util

from python.runfiles import Runfiles

VERBOSE = False
test_count = 0

r = Runfiles.Create()
conformance_pb2_path = Path(r.Rlocation("protobuf+/conformance/conformance_pb2.py"))    
spec = importlib.util.spec_from_file_location("conformance_pb2", str(conformance_pb2_path))
assert spec, "spec_from_file_location cannot be None"
conformance_pb2 = importlib.util.module_from_spec(spec)
assert spec.loader, "spec.loader cannot be None"
spec.loader.exec_module(conformance_pb2)

def do_test_io():
  length_bytes = sys.stdin.buffer.read(4)
  if len(length_bytes) == 0:
    return False  # EOF
  elif len(length_bytes) != 4:
    raise IOError("I/O error")

  length = struct.unpack("<I", length_bytes)[0]
  serialized_request = sys.stdin.buffer.read(length)
  if len(serialized_request) != length:
    raise IOError("I/O error")

  request = conformance_pb2.ConformanceRequest()
  request.ParseFromString(serialized_request)

  response = conformance_pb2.ConformanceResponse()
  response.json_payload = "{junk: 1}"
  response.protobuf_payload = "junk".encode("utf-8")

  serialized_response = response.SerializeToString()
  sys.stdout.buffer.write(struct.pack("<I", len(serialized_response)))
  sys.stdout.buffer.write(serialized_response)
  sys.stdout.buffer.flush()

  if VERBOSE:
    sys.stderr.write(f"conformance_python: {request=}\n")

  global test_count
  test_count += 1

  return True


while True:
  if not do_test_io():
    sys.stderr.write(
        "All fails testee: received EOF from test runner"
        f"after {test_count} tests, exiting.\n"
    )
    break
