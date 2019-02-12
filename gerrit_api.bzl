load("//tools:maven_jar.bzl", "maven_jar")
load("//:bouncycastle.bzl", "bouncycastle_repos")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.16.5"

def gerrit_api():
    bouncycastle_repos()

    maven_jar(
        name = "gerrit_plugin_api",
        artifact = "com.google.gerrit:gerrit-plugin-api:" + VER,
        sha1 = "d8d87281636b59be2509be07b33ba56e0d6c5c5d",
    )
    maven_jar(
        name = "gerrit_acceptance_framework",
        artifact = "com.google.gerrit:gerrit-acceptance-framework:" + VER,
        sha1 = "9d113e2ca789e617ab3c2cb6e18c93dc506090b0",
    )
    native.bind(
        name = "gerrit-plugin-api",
        actual = "@gerrit_plugin_api//jar",
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
        name = "gerrit-acceptance-framework-neverlink",
        actual = "@gerrit_acceptance_framework//jar:neverlink",
    )
