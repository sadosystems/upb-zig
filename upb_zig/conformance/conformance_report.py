#!/usr/bin/env python3
"""Parse conformance test output and generate a category report."""

import re
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Literal

REQUIREMENT_LEVELS = ("Required", "Recommended")


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

    if zig_protobuf_result is not None:
        zp_by_cat, zp_by_req = _count_failures(zig_protobuf_result)

        zp_req_badge = "![zig_protobuf_required](.github/badges/zig_protobuf_required.svg)"
        zp_rec_badge = "![zig_protobuf_recommended](.github/badges/zig_protobuf_recommended.svg)"
        zp_overall_badge = "![zig_protobuf_overall](.github/badges/zig_protobuf_overall.svg)"

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
