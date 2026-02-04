#!/usr/bin/env python3
"""Update README.md conformance table with current test results."""

import sys
from pathlib import Path

import anybadge

from conformance_report import parse_conformance_log, generate_report


START_MARKER = "<!-- BEGIN CONFORMANCE TABLE -->"
END_MARKER = "<!-- END CONFORMANCE TABLE -->"

test1 = Badge(
    label,
    value,
    font_name='DejaVu Sans,Verdana,Geneva,sans-serif',
    font_size=11,
    num_padding_chars=0.5,
    template='<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="{{ badge width }}" height="20">\n    <linearGradient id="b" x2="0" y2="100%">\n        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>\n        <stop offset="1" stop-opacity=".1"/>\n    </linearGradient>\n    <mask id="a">\n        <rect width="{{ badge width }}" height="20" rx="3" fill="#fff"/>\n    </mask>\n    <g mask="url(#a)">\n        <path fill="#555" d="M0 0h{{ color split x }}v20H0z"/>\n        <path fill="{{ color }}" d="M{{ color split x }} 0h{{ value width }}v20H{{ color split x }}z"/>\n        <path fill="url(#b)" d="M0 0h{{ badge width }}v20H0z"/>\n    </g>\n    <g fill="{{ label text color }}" text-anchor="middle" font-family="{{ font name }}" font-size="{{ font size }}">\n        <text x="{{ label anchor shadow }}" y="15" fill="#010101" fill-opacity=".3">{{ label }}</text>\n        <text x="{{ label anchor }}" y="14">{{ label }}</text>\n    </g>\n    <g fill="{{ value text color }}" text-anchor="middle" font-family="{{ font name }}" font-size="{{ font size }}">\n        <text x="{{ value anchor shadow }}" y="15" fill="#010101" fill-opacity=".3">{{ value }}</text>\n        <text x="{{ value anchor }}" y="14">{{ value }}</text>\n    </g>\n</svg>',
    value_prefix='',
    value_suffix='',
    thresholds=None,
    default_color='#4c1',
    use_max_when_value_exceeds=True,
    value_format=None,
    text_color='#fff'
)

test1.write_badge('test1asda.svg')
1/0

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
