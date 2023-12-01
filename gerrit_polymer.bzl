load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def gerrit_polymer():
    http_archive(
        name = "build_bazel_rules_nodejs",
        sha256 = "c077680a307eb88f3e62b0b662c2e9c6315319385bc8c637a861ffdbed8ca247",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/5.1.0/rules_nodejs-5.1.0.tar.gz"],
    )
