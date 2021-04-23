load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def gerrit_polymer():
    http_archive(
        name = "build_bazel_rules_nodejs",
        sha256 = "1134ec9b7baee008f1d54f0483049a97e53a57cd3913ec9d6db625549c98395a",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/3.4.0/rules_nodejs-3.4.0.tar.gz"],
    )
