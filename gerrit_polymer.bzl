load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def gerrit_polymer():
    http_archive(
        name = "build_bazel_rules_nodejs",
        sha256 = "a1295b168f183218bc88117cf00674bcd102498f294086ff58318f830dd9d9d1",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/5.8.5/rules_nodejs-5.8.5.tar.gz"],
    )
