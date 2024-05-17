load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def gerrit_polymer():
    http_archive(
	name = "rules_nodejs",
	patch_args = ["-p1"],
	patches = ["@com_googlesource_gerrit_bazlets//tools:rules_nodejs-5.8.4-node_versions.bzl.patch"],
	sha256 = "8fc8e300cb67b89ceebd5b8ba6896ff273c84f6099fc88d23f24e7102319d8fd",
	urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/5.8.4/rules_nodejs-core-5.8.4.tar.gz"],
    )

    http_archive(
        name = "build_bazel_rules_nodejs",
        sha256 = "94070eff79305be05b7699207fbac5d2608054dd53e6109f7d00d923919ff45a",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/5.8.2/rules_nodejs-5.8.2.tar.gz"],
    )
