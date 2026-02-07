import json
import re
from typing import Any
from pathlib import Path
from dataclasses import dataclass
from copy import deepcopy

import click

JSONish = dict[str, "bool | JSONish"]

@dataclass
class SectionResult():
    total: int
    passing: int

    def percent_passing(self):
        return self.passing / self.total * 100
    
    def __repr__(self) -> str:
        percent = self.percent_passing()
        passing = self.passing
        total = self.total
        return f"{percent:.1f}% ({passing}/{total})"

    
def section_result(tree: JSONish) -> SectionResult:
    return SectionResult(
        total = count_tests(tree),
        passing = count_passing_tests(tree) 
    )

def pull_out_failing_tests(as_str: str) -> list[str]:
    second_half = as_str.split("--add /failing_tests.txt")[1].strip()
    middle = second_half.split("Failed to open file: /failing_tests.txt")[0].strip()
    lines = middle.split("\n")
    failing_tests_sans_comments = [l.split(" # ")[0].strip() for l in lines]
    return failing_tests_sans_comments

def all_tests_as_dict_from_all_fails(as_str: str) -> JSONish:
    all_tests: JSONish = {}
    failing_tests = pull_out_failing_tests(as_str)
    for test in failing_tests:
        # Setting all tests to pass.
        set_test_result(all_tests, test, True)
    return all_tests

def set_test_result(tree: JSONish, test: str, result: bool) -> None:
    """Mutates `tree`"""
    parts = test.split(".")
    node = tree # cant we get rid of this 
    for key in parts[:-1]:
        assert isinstance(node, dict)
        node = node.setdefault(key, {})    
    assert isinstance(node, dict)
    node[parts[-1]] = result

def count_tests(tree: JSONish | bool) -> int:
    match tree:
        case dict():
            return sum(count_tests(v) for v in tree.values()) # type: ignore
        case bool():
            return 1
        case _:
            raise ValueError("unreachable")

def count_passing_tests(tree: JSONish | bool) -> int:
    match tree:
        case dict():
            return sum(count_passing_tests(v) for v in tree.values()) # type: ignore
        case bool():
            return int(tree)
        case _:
            raise ValueError("unreachable")

def set_test_result_existing(tree: JSONish, test: str, result: bool) -> None:
    parts = test.split(".")
    node: Any = tree
    walked: list[str] = []

    # Walk all but the leaf, requiring every intermediate key to exist.
    for key in parts[:-1]:
        walked.append(key)
        if not isinstance(node, dict):
            raise TypeError(
                f"Expected dict at {'.'.join(walked[:-1]) or '<root>'}, "
                f"but found {type(node).__name__} while resolving {test!r}"
            )
        if key not in node:
            raise KeyError(
                f"Missing path component {key!r} at {'.'.join(walked[:-1]) or '<root>'} "
                f"while resolving {test!r}"
            )
        node = node[key]

    # Set the leaf, requiring it to exist.
    leaf = parts[-1]
    if not isinstance(node, dict):
        raise TypeError(
            f"Expected dict at {'.'.join(walked) or '<root>'}, "
            f"but found {type(node).__name__} while setting leaf {leaf!r} of {test!r}"
        )
    if leaf not in node:
        raise KeyError(
            f"Missing leaf {leaf!r} under {'.'.join(walked) or '<root>'} "
            f"while resolving {test!r}"
        )

    node[leaf] = result

        
def apply_fails_to_perfect_report(fails: str, perfect_report: JSONish) -> None:
    """Mutates `perfect_report`"""
    failing_tests = pull_out_failing_tests(fails)
    for test in failing_tests:
        # Setting all present tests to fail.
        set_test_result_existing(perfect_report, test, False)

def get_subtree_by_path(report: JSONish, path: list[str]) -> JSONish:
    """Return the subtree/value at report[path[0]]...[path[-1]]."""
    node: Any = report
    for part in path:
        if not isinstance(node, dict):
            raise KeyError(f"Path {'/'.join(path)} hits non-dict before '{part}'")
        node = node[part]
        assert isinstance(node, dict)
    return node

def generaterate_markdown_row(path: list[str], reports: list[JSONish]) -> str:
    results: list[SectionResult] = []
    for report in reports:
        sub_tree = get_subtree_by_path(report, path)
        result = section_result(sub_tree)
        results.append(result)

    str_results: list[str] = [str(r) for r in results]
    if path:
        str_results = [" ".join(path)] + str_results
    else:
        str_results = ["Overall"] + str_results
    return " | ".join(str_results)

def generate_markdown_table(rows: list[list[str]], reports: list[JSONish], names: list[str]) -> str:
    
    header = "|".join(["Category"] + [n for n in names])
    header_bottom_row = "|".join(["---------" for _ in range(1+ len(reports))])

    str_rows: list[str] = [header, header_bottom_row] 

    for row in rows:
        str_rows.append(generaterate_markdown_row(row, reports))
    return "\n".join(str_rows)

@click.command()
@click.option(
    "-a",
    "--all-tests",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="txt file that contains a result from a testee that fails all conformance tests"
)
@click.option(
    "-u",
    "--upb-fails",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="txt file that contains a result from the upb zig testee"
)
@click.option(
    "-u",
    "--zig-pb-fails",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="txt file that contains a result from the zig-protobuf testee"
)
def handle_input(all_tests: Path, upb_fails: Path, zig_pb_fails: Path):
    all_tests_fails_str = all_tests.read_text()
    all_tests_json = all_tests_as_dict_from_all_fails(all_tests_fails_str)

    upb_fails_str = upb_fails.read_text()
    upb_zig_report = deepcopy(all_tests_json)
    apply_fails_to_perfect_report(upb_fails_str, upb_zig_report)

    zig_protobuf_fails_str = zig_pb_fails.read_text()
    zig_protobuf_report = deepcopy(all_tests_json)
    apply_fails_to_perfect_report(zig_protobuf_fails_str, zig_protobuf_report)

    rows: list[list[str]] = [
        [],
        ["Required"],
        ["Required", "Proto2"],
        ["Required", "Proto3"],
        ["Required", "Editions_Proto2"],
        ["Required", "Editions_Proto3"],
        ["Recommended"],
        ["Recommended", "Proto2"],
        ["Recommended", "Proto3"],
        ["Recommended", "Editions_Proto2"],
        ["Recommended", "Editions_Proto3"],
    ]

    reports = [upb_zig_report, zig_protobuf_report, all_tests_json]

    names = ["upb-zig", "zig-protobuf", "All Pass"]
    table_md = generate_markdown_table(rows, reports, names)
    print(table_md)


if __name__ == "__main__":
    handle_input()
