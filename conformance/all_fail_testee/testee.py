import sys
import struct
from google.protobuf import json_format
from google.protobuf import message
from google.protobuf import text_format

from python.runfiles import Runfiles
from pathlib import Path
import importlib.util

VERBOSE = False
test_count = 0

r = Runfiles.Create()
conformance_pb2_path = Path(r.Rlocation("protobuf+/conformance/conformance_pb2.py"))    
spec = importlib.util.spec_from_file_location("conformance_pb2", str(conformance_pb2_path))
conformance_pb2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(conformance_pb2)

print(conformance_pb2)


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
