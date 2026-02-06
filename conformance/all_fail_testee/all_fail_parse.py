from subprocess import check_output
from python.runfiles import Runfiles
r = Runfiles.Create()
path = r.Rlocation("protobuf+/conformance/conformance_test_runner")
import subprocess
import signal

p = subprocess.run(
    path,
    stderr=subprocess.PIPE,
    text=True,
    check=False,
)
err_str = (p.stderr or p.stdout or "").strip()
lines = err_str.split("\n")
assert len(lines) == 4929, f"got a new number of lines: {len(lines)}"

# for line in lines:
#     print("Required." in line)



print("WOW THATS GOOD")