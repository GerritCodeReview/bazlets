load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def gerrit_polymer():
    http_archive(
        name = "build_bazel_rules_nodejs",
        sha256 = "94070eff79305be05b7699207fbac5d2608054dd53e6109f7d00d923919ff45a",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/5.8.2/rules_nodejs-5.8.2.tar.gz"],
    )
