# Python utilities for conformance testing

# Python library for parsing conformance output and generating report (markdown table)
py_library(
    name = "conformance_report_lib",
    srcs = ["conformance_report.py"],
    visibility = ["//upb_zig/conformance:__pkg__"],
)

# Check that README conformance table is up to date
py_binary(
    name = "check_readme_conformance",
    srcs = ["check_readme_conformance.py"],
    deps = [":conformance_report_lib"],
    visibility = ["//upb_zig/conformance:__pkg__"],
)

# Update README.md with current conformance results
py_binary(
    name = "update_readme_conformance",
    srcs = ["update_readme_conformance.py"],
    deps = [":conformance_report_lib"],
    python_version = "PY3",
    visibility = ["//upb_zig/conformance:__pkg__"],
)
