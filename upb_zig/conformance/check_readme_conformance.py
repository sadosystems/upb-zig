#!/usr/bin/env python3
"""Check that README.md conformance table matches current test results."""

import sys
from pathlib import Path

from conformance_report import parse_conformance_log, generate_report


START_MARKER = "<!-- BEGIN CONFORMANCE TABLE -->"
END_MARKER = "<!-- END CONFORMANCE TABLE -->"


def extract_table_from_report(report: str) -> str:
    """Extract just the table portion from the full report."""
    lines = report.split("\n")
    start_idx = next((i for i, line in enumerate(lines) if line.startswith("|")), None)
    if start_idx is None:
        return ""
    table_lines = lines[start_idx:]
    while table_lines and table_lines[-1] == "":
        table_lines.pop()
    return "\n".join(table_lines)


def extract_table_from_readme(readme_content: str) -> str:
    """Extract content between conformance table markers."""
    start_idx = readme_content.find(START_MARKER)
    end_idx = readme_content.find(END_MARKER)
    if start_idx == -1 or end_idx == -1:
        return ""
    return readme_content[start_idx + len(START_MARKER):end_idx].strip()


def main():
    if len(sys.argv) < 2:
        print("Usage: check_readme_conformance.py <readme_file>", file=sys.stderr)
        print("       Reads conformance log from stdin", file=sys.stderr)
        sys.exit(1)

    readme_path = Path(sys.argv[1])

    # Parse conformance log from stdin
    log_content = sys.stdin.read()
    result = parse_conformance_log(log_content)
    report = generate_report(result)
    expected_table = extract_table_from_report(report)

    # Read actual table from README
    actual_table = extract_table_from_readme(Path(readme_path).read_text(encoding="utf-8"))

    if expected_table == actual_table:
        print("README conformance table is up to date.")
        sys.exit(0)
    else:
        print("README.md conformance table is out of date. To fix, run:")
        print("")
        print("  bazel run //upb_zig/conformance:update_conformance_report")
        sys.exit(1)


if __name__ == "__main__":
    main()
