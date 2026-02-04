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


def generate_badges(result: ConformanceResult, badges_dir: Path):
    """Generate SVG progress bar badges for conformance percentages."""
    badges_dir.mkdir(parents=True, exist_ok=True)

    failed_by_req: defaultdict[str, int] = defaultdict(int)
    for test in result.failed:
        failed_by_req[test.requirement_level] += 1

    req_failures = failed_by_req.get("Required", 0)
    rec_failures = failed_by_req.get("Recommended", 0)
    total_run = result.num_passed + result.num_failed

    badges: dict[str, float] = {
        "required": 100 * (TOTAL_REQUIRED - req_failures) / TOTAL_REQUIRED,
        "recommended": 100 * (TOTAL_RECOMMENDED - rec_failures) / TOTAL_RECOMMENDED,
        "overall": 100 * result.num_passed / total_run if total_run > 0 else 0,
    }

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

    # Generate badges
    badges_dir = readme_path.parent / ".github" / "badges"
    generate_badges(result, badges_dir)
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
