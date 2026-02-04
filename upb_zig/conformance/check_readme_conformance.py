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
    import argparse

    parser = argparse.ArgumentParser(description="Check README.md conformance table is up to date")
    parser.add_argument("readme_file", help="Path to README.md")
    parser.add_argument("--zig-protobuf-log", help="Path to zig-protobuf conformance log file")
    args = parser.parse_args()

    readme_path = Path(args.readme_file)

    # Parse upb-zig conformance log from stdin
    log_content = sys.stdin.read()
    result = parse_conformance_log(log_content)

    # Parse zig-protobuf conformance log if provided
    zig_protobuf_result = None
    if args.zig_protobuf_log:
        zp_log = Path(args.zig_protobuf_log).read_text(encoding="utf-8")
        zig_protobuf_result = parse_conformance_log(zp_log)

    report = generate_report(result, zig_protobuf_result=zig_protobuf_result)
    expected_table = extract_table_from_report(report)

    # Read actual table from README
    actual_table = extract_table_from_readme(readme_path.read_text(encoding="utf-8"))

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
