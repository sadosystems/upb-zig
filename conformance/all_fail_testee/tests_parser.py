from pprint import pprint
from typing import Any
from pathlib import Path
from subprocess import check_output
from python.runfiles import Runfiles
r = Runfiles.Create()
path = Path(r.Rlocation("_main/conformance/all_fail_testee/all_tests.txt"))

file_content = path.read_text()
second_half = file_content.split("--add /failing_tests.txt")[1].strip()
middle = second_half.split("Failed to open file: /failing_tests.txt")[0].strip()

lines = middle.split("\n")
tests = [l.split(" # ")[0].strip() for l in lines]

JSONish = dict[str, Any]

def add_path(tree: JSONish, parts: list[str]) -> None:
    node = tree
    for key in parts[:-1]:
        assert isinstance(node, dict)
        node = node.setdefault(key, {})    
    assert isinstance(node, dict)
    node[parts[-1]] = True

all_pass_json: JSONish = {}

def count_tests(tree: JSONish | bool) -> int:
    match tree:
        case dict():
            return sum(count_tests(v) for v in tree.values())
        case bool():
            return 1
        case _:
            raise ValueError("unreachable")

for test in tests:
    add_path(all_pass_json, test.split("."))


print(f"{len(lines)}")
print(f"{count_tests(all_pass_json['Recommended'])}")

print(f"{count_tests(all_pass_json['Required']['Proto2'])}")
print(f"{count_tests(all_pass_json['Required']['Proto3'])}")

