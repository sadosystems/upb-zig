#!/usr/bin/env python3
"""Parse conformance test output and generate a category report."""

import re
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Literal

REQUIREMENT_LEVELS = ("Required", "Recommended")

def normalize_proto_version(version: str) -> Literal["Proto2" , "Proto3"] | str: # Editions_*
    if "Proto2" in version:
        return "Proto2"
    if "Proto3" in version:
        return "Proto3"
    return version
    
@dataclass
class ConformanceTest:
    """Parsed conformance test value."""
    requirement_level: Literal["Required" , "Recommended"] 
    proto_version: Literal["Proto2" , "Proto3"] | str # Proto2 / Proto3 / Editions_*

    @classmethod
    def from_str(cls, as_str: str) -> "ConformanceTest":
        parts = as_str.split(".")

        assert len(parts) >= 2, "What"
        
        requirement_level = parts[0]
        assert requirement_level in REQUIREMENT_LEVELS, f"Must be one of {REQUIREMENT_LEVELS}"

        proto_version = parts[1]
        proto_version = normalize_proto_version(proto_version)

        return cls(
            requirement_level=requirement_level,
            proto_version=proto_version
            )

@dataclass
class ConformanceResult:
    """Parsed conformance test results."""
    failed: list[ConformanceTest] = field(default_factory=list[ConformanceTest])
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
    lines = ["# Conformance Test Report", ""]

    failed_by_category: defaultdict[tuple[str, str], int] = defaultdict(int)
    for test in result.failed:
        failed_by_category[(test.requirement_level, test.proto_version)] += 1

    total_run = result.num_passed + result.num_failed

    def get_pass_indicator(req: str, proto: str) -> str:
        failed = failed_by_category.get((req, proto), 0)
        return "PASS" if failed == 0 else f"FAIL ({failed})"

    lines.append(
        "| Implementation | Proto2 Required | Proto3 Required | Proto2 Recommended | Proto3 Recommended |")
    lines.append("|----------------|-----------------|-----------------|--------------------|--------------------|")
    lines.append(
        f"| {impl_name} "
        f"| {get_pass_indicator('Required', 'Proto2')} "
        f"| {get_pass_indicator('Required', 'Proto3')} "
        f"| {get_pass_indicator('Recommended', 'Proto2')} "
        f"| {get_pass_indicator('Recommended', 'Proto3')} |"
    )

    lines.append("")
    if total_run > 0:
        lines.append(f"**Overall**: {result.num_passed}/{total_run} ({100 * result.num_passed / total_run:.1f}% passing)")
    else:
        lines.append("**Overall**: No tests run")

    if result.skipped > 0:
        lines.append(f"**Skipped**: {result.skipped}")

    if result.expected_failures > 0:
        lines.append(f"**Expected failures**: {result.expected_failures}")

    return "\n".join(lines)
