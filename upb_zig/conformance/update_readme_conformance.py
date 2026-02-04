#!/usr/bin/env python3
"""Update README.md conformance table with current test results."""

import sys
from collections import defaultdict
from pathlib import Path

from conformance_report import parse_conformance_log, generate_report, TOTAL_REQUIRED, TOTAL_RECOMMENDED, ConformanceResult


START_MARKER = "<!-- BEGIN CONFORMANCE TABLE -->"
END_MARKER = "<!-- END CONFORMANCE TABLE -->"

BADGE_WIDTH = 120
BADGE_HEIGHT = 20


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


def _generate_progress_bar_svg(percentage: float) -> str:
    """Generate a progress bar SVG badge with centered text."""
    bar_width = BADGE_WIDTH * percentage / 100
    color = _bar_color(percentage)
    text = f"{percentage:.1f}%"

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


def _badges_for_result(
    result: ConformanceResult,
    prefix: str = "",
) -> dict[str, float]:
    """Compute badge percentages for a conformance result."""
    failed_by_req: defaultdict[str, int] = defaultdict(int)
    for test in result.failed:
        failed_by_req[test.requirement_level] += 1

    req_failures = failed_by_req.get("Required", 0)
    rec_failures = failed_by_req.get("Recommended", 0)
    total_run = result.num_passed + result.num_failed

    return {
        f"{prefix}required": 100 * (TOTAL_REQUIRED - req_failures) / TOTAL_REQUIRED,
        f"{prefix}recommended": 100 * (TOTAL_RECOMMENDED - rec_failures) / TOTAL_RECOMMENDED,
        f"{prefix}overall": 100 * result.num_passed / total_run if total_run > 0 else 0,
    }


def generate_badges(
    result: ConformanceResult,
    badges_dir: Path,
    zig_protobuf_result: ConformanceResult | None = None,
):
    """Generate SVG progress bar badges for conformance percentages."""
    badges_dir.mkdir(parents=True, exist_ok=True)

    badges = _badges_for_result(result)
    if zig_protobuf_result is not None:
        badges.update(_badges_for_result(zig_protobuf_result, prefix="zig_protobuf_"))

    for name, pct in badges.items():
        svg = _generate_progress_bar_svg(pct)
        (badges_dir / f"{name}.svg").write_text(svg, encoding="utf-8")


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
