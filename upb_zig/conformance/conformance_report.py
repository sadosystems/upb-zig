#!/usr/bin/env python3
"""Parse conformance test output and generate a category report."""

import re
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

REQUIREMENT_LEVELS = ("Required", "Recommended")

START_MARKER = "<!-- BEGIN CONFORMANCE TABLE -->"
END_MARKER = "<!-- END CONFORMANCE TABLE -->"

BADGE_WIDTH = 120
BADGE_HEIGHT = 20


def normalize_proto_version(version: str) -> Literal["Proto2", "Proto3"] | str:
    """Normalize Editions_Proto2/Proto3 to just Proto2/Proto3."""
    if "Proto2" in version:
        return "Proto2"
    if "Proto3" in version:
        return "Proto3"
    return version


def get_test_format(test_type: str) -> str:
    """Map test type to format category."""
    if "Json" in test_type:
        return "JSON"
    if "TextFormat" in test_type:
        return "Text format"
    # ProtobufInput or similar = wire format
    return "Wire format"


@dataclass
class ConformanceTest:
    """Parsed conformance test value."""
    requirement_level: Literal["Required", "Recommended"]
    proto_version: Literal["Proto2", "Proto3"] | str
    test_format: str  # "Wire format", "JSON", "Text format"

    @classmethod
    def from_str(cls, as_str: str) -> "ConformanceTest":
        parts = as_str.split(".")

        assert len(parts) >= 3, f"Expected at least 3 parts in test name: {as_str}"

        requirement_level = parts[0]
        assert requirement_level in REQUIREMENT_LEVELS, f"Must be one of {REQUIREMENT_LEVELS}"

        proto_version = normalize_proto_version(parts[1])
        test_type = parts[2]  # e.g., JsonInput, ProtobufInput, TextFormatInput
        test_format = get_test_format(test_type)

        return cls(
            requirement_level=requirement_level,
            proto_version=proto_version,
            test_format=test_format,
        )


@dataclass
class ConformanceResult:
    """Parsed conformance test results."""
    failed: list[ConformanceTest] = field(default_factory=list)
    num_passed: int = 0
    skipped: int = 0
    expected_failures: int = 0
    unexpected_failures: int = 0

    @property
    def num_failed(self):
        return len(self.failed)


def parse_conformance_log(log: str) -> ConformanceResult:
    """Parse conformance test runner output into structured data."""
    result = ConformanceResult()

    for match in re.finditer(r"^ERROR, test=([^:]+):", log, re.MULTILINE):
        result.failed.append(ConformanceTest.from_str(match.group(1)))

    summary_match = re.search(
        r"(\d+) successes, (\d+) skipped, (\d+) expected failures, (\d+) unexpected failures",
        log
    )
    if summary_match:
        result.num_passed = int(summary_match.group(1))
        result.skipped = int(summary_match.group(2))
        result.expected_failures = int(summary_match.group(3))
        result.unexpected_failures = int(summary_match.group(4))

    return result


# Total test counts for edition 2023 (from protobuf-conformance baseline)
# https://github.com/bufbuild/protobuf-conformance
TOTAL_REQUIRED = 4267
TOTAL_RECOMMENDED = 1300


def _count_failures(result: ConformanceResult):
    """Count failures by category and requirement level."""
    by_category: defaultdict[tuple[str, str, str], int] = defaultdict(int)
    by_req: defaultdict[str, int] = defaultdict(int)
    for test in result.failed:
        by_category[(test.requirement_level, test.proto_version, test.test_format)] += 1
        by_req[test.requirement_level] += 1
    return by_category, by_req


def _get_status(failed_by_category, req: str, proto: str | None, fmt: str) -> str:
    """Get failure count string for a category. If proto is None, combine Proto2 and Proto3."""
    if proto is None:
        failed = (failed_by_category.get((req, "Proto2", fmt), 0) +
                  failed_by_category.get((req, "Proto3", fmt), 0))
    else:
        failed = failed_by_category.get((req, proto, fmt), 0)
    return f"{failed} failures"


def generate_report(
    result: ConformanceResult,
    impl_name: str = "upb-zig",
    zig_protobuf_result: ConformanceResult | None = None,
) -> str:
    """Generate a markdown report from parsed results."""
    lines = []

    upb_by_cat, upb_by_req = _count_failures(result)

    req_badge = "![required](.github/badges/required.svg)"
    rec_badge = "![recommended](.github/badges/recommended.svg)"
    overall_badge = "![overall](.github/badges/overall.svg)"

    zp_req_badge = "![required](.github/badges/zig_protobuf_required.svg)"
    zp_rec_badge = "![recommended](.github/badges/zig_protobuf_recommended.svg)"
    zp_overall_badge = "![overall](.github/badges/zig_protobuf_overall.svg)"

    if zig_protobuf_result is not None:
        zp_by_cat, zp_by_req = _count_failures(zig_protobuf_result)

        def zp_status(req, proto, fmt):
            return _get_status(zp_by_cat, req, proto, fmt)

        zp_col = {
            "req": zp_req_badge,
            "rec": zp_rec_badge,
            "overall": zp_overall_badge,
            "req_wire_p2": zp_status("Required", "Proto2", "Wire format"),
            "req_wire_p3": zp_status("Required", "Proto3", "Wire format"),
            "req_json_p2": zp_status("Required", "Proto2", "JSON"),
            "req_json_p3": zp_status("Required", "Proto3", "JSON"),
            "rec_wire": zp_status("Recommended", None, "Wire format"),
            "rec_json": zp_status("Recommended", None, "JSON"),
        }
    else:
        zp_col = {k: "N/A" for k in [
            "req", "rec", "overall",
            "req_wire_p2", "req_wire_p3", "req_json_p2", "req_json_p3",
            "rec_wire", "rec_json",
        ]}

    def upb_status(req, proto, fmt):
        return _get_status(upb_by_cat, req, proto, fmt)

    # Build table
    lines.append(f"| Category | {impl_name} | zig-protobuf |")
    lines.append("|----------|-------------|--------------|")
    lines.append(f"| **Required** | {req_badge} | {zp_col['req']} |")
    lines.append(f"| Wire format (proto2) | {upb_status('Required', 'Proto2', 'Wire format')} | {zp_col['req_wire_p2']} |")
    lines.append(f"| Wire format (proto3) | {upb_status('Required', 'Proto3', 'Wire format')} | {zp_col['req_wire_p3']} |")
    lines.append(f"| JSON (proto2) | {upb_status('Required', 'Proto2', 'JSON')} | {zp_col['req_json_p2']} |")
    lines.append(f"| JSON (proto3) | {upb_status('Required', 'Proto3', 'JSON')} | {zp_col['req_json_p3']} |")
    lines.append(f"| **Recommended** | {rec_badge} | {zp_col['rec']} |")
    lines.append(f"| Wire format | {upb_status('Recommended', None, 'Wire format')} | {zp_col['rec_wire']} |")
    lines.append(f"| JSON | {upb_status('Recommended', None, 'JSON')} | {zp_col['rec_json']} |")
    lines.append(f"| **Overall** | {overall_badge} | {zp_col['overall']} |")

    return "\n".join(lines)


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


# Badge SVG generation

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


def generate_badges(
    result: ConformanceResult,
    badges_dir: Path,
    zig_protobuf_result: ConformanceResult | None = None,
):
    """Generate SVG progress bar badges for conformance percentages."""
    badges_dir.mkdir(parents=True, exist_ok=True)

    failed_by_req: defaultdict[str, int] = defaultdict(int)
    for test in result.failed:
        failed_by_req[test.requirement_level] += 1

    req_failures = failed_by_req.get("Required", 0)
    rec_failures = failed_by_req.get("Recommended", 0)
    total_run = result.num_passed + result.num_failed

    # upb-zig runs the full suite so we can use the known totals
    badges: dict[str, float] = {
        "required": 100 * (TOTAL_REQUIRED - req_failures) / TOTAL_REQUIRED,
        "recommended": 100 * (TOTAL_RECOMMENDED - rec_failures) / TOTAL_RECOMMENDED,
        "overall": 100 * result.num_passed / total_run if total_run > 0 else 0,
    }

    if zig_protobuf_result is not None:
        zp_failed_by_req: defaultdict[str, int] = defaultdict(int)
        for test in zig_protobuf_result.failed:
            zp_failed_by_req[test.requirement_level] += 1

        zp_req_failures = zp_failed_by_req.get("Required", 0)
        zp_rec_failures = zp_failed_by_req.get("Recommended", 0)

        # Skipped tests count as failures since they represent unsupported features.
        # Distribute skips proportionally across required/recommended.
        zp_total_run = (zig_protobuf_result.num_passed + zig_protobuf_result.num_failed
                        + zig_protobuf_result.skipped)
        zp_total_tests = TOTAL_REQUIRED + TOTAL_RECOMMENDED

        badges["zig_protobuf_required"] = max(0.0, 100 * (TOTAL_REQUIRED - zp_req_failures - zig_protobuf_result.skipped * TOTAL_REQUIRED / zp_total_tests) / TOTAL_REQUIRED)
        badges["zig_protobuf_recommended"] = max(0.0, 100 * (TOTAL_RECOMMENDED - zp_rec_failures - zig_protobuf_result.skipped * TOTAL_RECOMMENDED / zp_total_tests) / TOTAL_RECOMMENDED)
        badges["zig_protobuf_overall"] = (
            100 * zig_protobuf_result.num_passed / zp_total_run if zp_total_run > 0 else 0
        )

    for name, pct in badges.items():
        svg = _generate_progress_bar_svg(pct)
        (badges_dir / f"{name}.svg").write_text(svg, encoding="utf-8")
