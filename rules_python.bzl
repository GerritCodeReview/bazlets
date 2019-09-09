load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

"""Bazel rule for fetching rules python dependency.
"""

def rules_python_repos():
    http_archive(
        name = "rules_python",
        sha256 = "b5bab4c47e863e0fbb77df4a40c45ca85f98f5a2826939181585644c9f31b97b",
        strip_prefix = "rules_python-9d68f24659e8ce8b736590ba1e4418af06ec2552",
        urls = ["https://github.com/bazelbuild/rules_python/archive/9d68f24659e8ce8b736590ba1e4418af06ec2552.tar.gz"],
    )
