load("//:bouncycastle.bzl", "bouncycastle_repos")
load("//tools:maven_jar.bzl", "maven_jar")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.15.14"

def gerrit_api():
    bouncycastle_repos()

    maven_jar(
        name = "gerrit_plugin_api",
        artifact = "com.google.gerrit:gerrit-plugin-api:" + VER,
        sha1 = "72b062a380b23c9b8186d4d69c5c75cd9495de9c",
    )
    maven_jar(
        name = "gerrit_plugin_gwtui",
        artifact = "com.google.gerrit:gerrit-plugin-gwtui:" + VER,
        sha1 = "799ad200d4482b78ebabd815de5be62e111cd8be",
        exclude = ["com/google/gwt/*"],
    )
    maven_jar(
        name = "gerrit_acceptance_framework",
        artifact = "com.google.gerrit:gerrit-acceptance-framework:" + VER,
        sha1 = "bb8c4bc73ab4e0d539cdf0e7fb11707621797cdb",
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
