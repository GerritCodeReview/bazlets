load("//tools:maven_jar.bzl", "maven_jar")
load("//:bouncycastle.bzl", "bouncycastle_repos")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.14.17"

def gerrit_api():
    bouncycastle_repos()

    maven_jar(
        name = "gerrit_plugin_api",
        artifact = "com.google.gerrit:gerrit-plugin-api:" + VER,
        sha1 = "65cc5a40d865f97da1b448b205e7ff64554b4188",
    )
    maven_jar(
        name = "gerrit_plugin_gwtui",
        artifact = "com.google.gerrit:gerrit-plugin-gwtui:" + VER,
        sha1 = "1004717abc1acb9788184bb2dd86a00a38c1cfc1",
        exclude = ["com/google/gwt/*"],
    )
    maven_jar(
        name = "gerrit_acceptance_framework",
        artifact = "com.google.gerrit:gerrit-acceptance-framework:" + VER,
        sha1 = "64166694cc5b596bb7418a945e768dbb11847c6e",
    )
    native.bind(
        name = "gerrit-plugin-api",
        actual = "@gerrit_plugin_api//jar",
    )
    native.bind(
        name = "gerrit-plugin-gwtui",
        actual = "@gerrit_plugin_gwtui//jar",
    )
    native.bind(
        name = "gerrit-acceptance-framework",
        actual = "@gerrit_acceptance_framework//jar",
    )
    native.bind(
        name = "gerrit-plugin-api-neverlink",
        actual = "@gerrit_plugin_api//jar:neverlink",
    )
    native.bind(
        name = "gerrit-plugin-gwtui-neverlink",
        actual = "@gerrit_plugin_gwtui//jar:neverlink",
    )
    native.bind(
        name = "gerrit-acceptance-framework-neverlink",
        actual = "@gerrit_acceptance_framework//jar:neverlink",
    )
