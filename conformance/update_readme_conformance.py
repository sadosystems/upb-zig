#!/usr/bin/env python3
"""Update README.md conformance table with current test results."""

import sys
from pathlib import Path

from conformance_report import (
    START_MARKER, END_MARKER,
    parse_conformance_log, generate_report, extract_table_from_report, generate_badges,
)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Update README.md conformance table")
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
    new_table = extract_table_from_report(report)

    # Generate badges
    badges_dir = readme_path.parent / ".github" / "badges"
    generate_badges(result, badges_dir, zig_protobuf_result=zig_protobuf_result)
    print(f"Generated badges in {badges_dir}")

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
