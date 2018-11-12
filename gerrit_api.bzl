load("//tools:maven_jar.bzl", "maven_jar")
load("//:bouncycastle.bzl", "bouncycastle_repos")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.15.7"

def gerrit_api():
    bouncycastle_repos()

    maven_jar(
        name = "gerrit_plugin_api",
        artifact = "com.google.gerrit:gerrit-plugin-api:" + VER,
        sha1 = "ce71aaaf71b633467b4e676233e9d8c4d923f3db",
    )
    maven_jar(
        name = "gerrit_plugin_gwtui",
        artifact = "com.google.gerrit:gerrit-plugin-gwtui:" + VER,
        sha1 = "ee888227cadeba8b4a26c83cf3ddd0827a5b18c6",
        exclude = ["com/google/gwt/*"],
    )
    maven_jar(
        name = "gerrit_acceptance_framework",
        artifact = "com.google.gerrit:gerrit-acceptance-framework:" + VER,
        sha1 = "1b2531b43bd02a6e6b50a5d6e23fef160c7954b0",
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
