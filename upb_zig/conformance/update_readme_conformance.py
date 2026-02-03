#!/usr/bin/env python3
"""Update README.md conformance table with current test results."""

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


def main():
    if len(sys.argv) < 2:
        print("Usage: update_readme_conformance.py <readme_file>", file=sys.stderr)
        print("       Reads conformance log from stdin", file=sys.stderr)
        sys.exit(1)

    readme_path = Path(sys.argv[1])

    # Parse conformance log from stdin
    log_content = sys.stdin.read()
    result = parse_conformance_log(log_content)
    report = generate_report(result)
    new_table = extract_table_from_report(report)

    # Read current README
    readme_content = readme_path.read_text(encoding="utf-8")

    # Find markers
    start_idx = readme_content.find(START_MARKER)
    end_idx = readme_content.find(END_MARKER)

    if start_idx == -1 or end_idx == -1:
        print("ERROR: Could not find conformance table markers in README.md", file=sys.stderr)
        sys.exit(1)

    # Build new content
    before = readme_content[:start_idx + len(START_MARKER)]
    after = readme_content[end_idx:]
    new_content = before + "\n" + new_table + "\n" + after

    # Write back
    readme_path.write_text(new_content, encoding="utf-8")
    print(f"Updated {readme_path} with new conformance table")


if __name__ == "__main__":
    main()
