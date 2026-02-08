import re
import sys
from typing import Any
from pathlib import Path
from dataclasses import dataclass
from copy import deepcopy

import click

START_MARKER = "<!-- BEGIN CONFORMANCE TABLE -->"
END_MARKER = "<!-- END CONFORMANCE TABLE -->"
BADGE_WIDTH = 120
BADGE_HEIGHT = 20

JSONish = dict[str, "bool | JSONish"]

@dataclass
class SectionResult():
    total: int
    passing: int

    def percent_passing(self):
        return self.passing / self.total * 100
    
    def get_badge_ref(self) -> str:
        unique_str = f"{self.passing}_{self.total}"
        return f"![{unique_str}](.github/badges/{unique_str}.svg)"
    
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

def set_test_result_existing(tree: JSONish | bool, test: str, result: bool) -> None:
    parts = test.split(".")
    walked: list[str] = []

    # Walk all but the leaf, requiring every intermediate key to exist.
    for key in parts[:-1]:
        walked.append(key)
        if not isinstance(tree, dict):
            raise TypeError(
                f"Expected dict at {'.'.join(walked[:-1]) or '<root>'}, "
                f"but found {tree.__class__.__name__} while resolving {test!r}"
            )
        if key not in tree:
            raise KeyError(
                f"Missing path component {key!r} at {'.'.join(walked[:-1]) or '<root>'} "
                f"while resolving {test!r}"
            )
        tree = tree[key]

    # Set the leaf, requiring it to exist.
    leaf = parts[-1]
    if not isinstance(test, dict):
        raise TypeError(
            f"Expected dict at {'.'.join(walked) or '<root>'}, "
            f"but found {tree.__class__.__name__} while setting leaf {leaf!r} of {test!r}"
        )
    if leaf not in test:
        raise KeyError(
            f"Missing leaf {leaf!r} under {'.'.join(walked) or '<root>'} "
            f"while resolving {test!r}"
        )

    tree[leaf] = result

        
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

    str_results: list[str] = [r.get_badge_ref() for r in results]
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

@click.group()
def cli():
    pass

@cli.command("gen_table")
@click.option(
    "--all-tests",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="txt file that contains a result from a testee that fails all conformance tests"
)
@click.option(
    "--upb-fails",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="txt file that contains a result from the upb zig testee"
)
@click.option(
    "--zig-pb-fails",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="txt file that contains a result from the zig-protobuf testee"
)
def gen_table(all_tests: Path, upb_fails: Path, zig_pb_fails: Path):
    all_tests_fails_str = all_tests.read_text()
    all_tests_json = all_tests_as_dict_from_all_fails(all_tests_fails_str)

    # upb-zig implementation
    upb_fails_str = upb_fails.read_text()
    upb_zig_report = deepcopy(all_tests_json)
    apply_fails_to_perfect_report(upb_fails_str, upb_zig_report)

    # zig-protobuf implementation
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
    reports = [upb_zig_report, zig_protobuf_report]
    names = ["upb-zig", "zig-protobuf"]

    table_md = generate_markdown_table(rows, reports, names)
    print(table_md)

def extract_table_from_readme(readme_content: str) -> str:
    """Extract content between conformance table markers."""
    start_idx = readme_content.find(START_MARKER)
    end_idx = readme_content.find(END_MARKER)
    if start_idx == -1 or end_idx == -1:
        return ""
    return readme_content[start_idx + len(START_MARKER):end_idx].strip() + "\n"

def get_updated_readme_str(readme_content: str, new_table: str) -> str:
    start_idx = readme_content.find(START_MARKER)
    end_idx = readme_content.find(END_MARKER)
    if start_idx == -1 or end_idx == -1:
        raise KeyError("ERROR: Could not find conformance table markers in README.md")

    before = readme_content[:start_idx + len(START_MARKER)]
    after = readme_content[end_idx:]
    new_content = before + "\n" + new_table + "\n" + after
    return new_content

def is_readme_table_outdated(readme: str, new_table: str) -> bool:
    current_table = extract_table_from_readme(readme)
    return current_table != new_table

# ----- Badge Gen -----
#  
def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t

def _bar_color(pct: float) -> str:
    """Smooth gradient from red (0%) -> orange (50%) -> green (100%)."""
    pct = max(0.0, min(100.0, pct))
    if pct < 60:
        t = pct / 60
        r = int(_lerp(180, 200, t))
        g = int(_lerp(60, 140, t))
        b = int(_lerp(55, 55, t))
    else:
        t = (pct - 60) / 40
        r = int(_lerp(200, 68, t))
        g = int(_lerp(140, 148, t))
        b = int(_lerp(55, 68, t))
    return f"#{r:02x}{g:02x}{b:02x}"


def gen_percent_bar_svg(passing: int, total: int) -> str:
    """Generate a progress bar SVG badge with centered text."""
    percentage = passing / total * 100
    bar_width = BADGE_WIDTH * percentage / 100
    color = _bar_color(percentage)
    text = f"{percentage:.1f}% ({passing}/{total})"

    if passing == 0:
        text = f"NA ({passing}/{total})"
        color = _bar_color(10)
        bar_width = BADGE_WIDTH

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{BADGE_WIDTH}" height="{BADGE_HEIGHT}">
  <rect width="{BADGE_WIDTH}" height="{BADGE_HEIGHT}" rx="3" fill="#555"/>
  <rect width="{bar_width}" height="{BADGE_HEIGHT}" rx="3" fill="{color}"/>
  <rect width="{BADGE_WIDTH}" height="{BADGE_HEIGHT}" rx="3" fill="url(#g)"/>
  <defs>
    <linearGradient id="g" x2="0" y2="100%">
      <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
      <stop offset="1" stop-opacity=".1"/>
    </linearGradient>
  </defs>
  <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
    <text x="{BADGE_WIDTH / 2}" y="15" fill="#010101" fill-opacity=".3">{text}</text>
    <text x="{BADGE_WIDTH / 2}" y="14">{text}</text>
  </g>
</svg>"""


def update_badges(workspace_dir: Path, badge_refs: list[str]):
    badges_dir = workspace_dir / ".github" / "badges"
    for badge in badge_refs:
        passing, total = badge.split("_")
        svg = gen_percent_bar_svg(int(passing), int(total))
        (badges_dir / f"{badge}.svg").write_text(svg, encoding="utf-8")

    ...

@cli.command('update')
@click.option(
    "--readme",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="path to the readme in the source tree"
)
@click.option(
    "--table",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="md file that contains the current table values"
)
def update(readme: Path, table: Path):
    readme_str = readme.read_text()
    table_str = table.read_text()
    if is_readme_table_outdated(readme_str, table_str):
        new_readme = get_updated_readme_str(readme_str, table_str)

        regex_results = re.findall(r'(.github/badges/(.*?).svg)', new_readme)
        badges = [b[1] for b in regex_results]
        update_badges(readme.parent, badges)

        readme.write_text(new_readme)
    else:
        click.echo('Readme is already up to date')

@cli.command('up-to-date')
@click.option(
    "--readme",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="path to the readme in the source tree"
)
@click.option(
    "--table",
    type=click.Path(file_okay=True, dir_okay=False, path_type=Path),
    help="md file that contains the current table values"
)
def up_to_date(readme: Path, table: Path):
    readme_str = readme.read_text()
    table_str = table.read_text()
    if is_readme_table_outdated(readme_str, table_str):
        click.echo("README.md conformance table is out of date. To fix, run:")
        click.echo("")
        click.echo("  bazel run //conformance:update_conformance_report")
        sys.exit(1)
    else:
        print("README conformance table is up to date.")
        sys.exit(0)


if __name__ == "__main__":
    cli()
