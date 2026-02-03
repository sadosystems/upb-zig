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


def generate_report(result: ConformanceResult, impl_name: str = "upb-zig") -> str:
    """Generate a markdown report from parsed results."""
    lines = []

    # Total test counts for edition 2023 (from protobuf-conformance baseline)
    # https://github.com/bufbuild/protobuf-conformance
    TOTAL_REQUIRED = 4267
    TOTAL_RECOMMENDED = 1300

    # Count failures by (requirement_level, proto_version, test_format)
    failed_by_category: defaultdict[tuple[str, str, str], int] = defaultdict(int)
    failed_by_req: defaultdict[str, int] = defaultdict(int)
    for test in result.failed:
        failed_by_category[(test.requirement_level, test.proto_version, test.test_format)] += 1
        failed_by_req[test.requirement_level] += 1

    total_run = result.num_passed + result.num_failed
    overall_pct = f"{100 * result.num_passed / total_run:.1f}%" if total_run > 0 else "N/A"

    req_failures = failed_by_req.get("Required", 0)
    rec_failures = failed_by_req.get("Recommended", 0)
    req_pct = f"{100 * (TOTAL_REQUIRED - req_failures) / TOTAL_REQUIRED:.1f}%"
    rec_pct = f"{100 * (TOTAL_RECOMMENDED - rec_failures) / TOTAL_RECOMMENDED:.1f}%"

    def get_status(req: str, proto: str | None, fmt: str) -> str:
        """Get status for a category. If proto is None, combine Proto2 and Proto3."""
        if proto is None:
            failed = (failed_by_category.get((req, "Proto2", fmt), 0) +
                      failed_by_category.get((req, "Proto3", fmt), 0))
        else:
            failed = failed_by_category.get((req, proto, fmt), 0)
        return f"{failed} failures"

    # Build table in desired format
    lines.append(f"| Category | {impl_name} | zig-protobuf |")
    lines.append("|----------|-------------|--------------|")
    lines.append(f"| **Required** | {req_pct} | N/A |")
    lines.append(f"| Wire format (proto2) | {get_status('Required', 'Proto2', 'Wire format')} | N/A |")
    lines.append(f"| Wire format (proto3) | {get_status('Required', 'Proto3', 'Wire format')} | N/A |")
    lines.append(f"| JSON (proto2) | {get_status('Required', 'Proto2', 'JSON')} | N/A |")
    lines.append(f"| JSON (proto3) | {get_status('Required', 'Proto3', 'JSON')} | N/A |")
    lines.append(f"| **Recommended** | {rec_pct} | N/A |")
    lines.append(f"| Wire format | {get_status('Recommended', None, 'Wire format')} | N/A |")
    lines.append(f"| JSON | {get_status('Recommended', None, 'JSON')} | N/A |")
    lines.append(f"| **Overall** | {overall_pct} | N/A |")

    return "\n".join(lines)
