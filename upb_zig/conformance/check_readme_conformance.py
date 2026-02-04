#!/usr/bin/env python3
"""Check that README.md conformance table matches current test results."""

import sys
from pathlib import Path

from conformance_report import (
    parse_conformance_log, generate_report,
    extract_table_from_report, extract_table_from_readme,
)


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
