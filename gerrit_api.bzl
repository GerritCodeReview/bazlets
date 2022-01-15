load("//:bouncycastle.bzl", "bouncycastle_repos")
load("//:gerrit_api_version.bzl", "gerrit_api_version")
load("//:rules_python.bzl", "rules_python_repos")
load("//tools:maven_jar.bzl", "MAVEN_LOCAL", "MAVEN_CENTRAL", "maven_jar")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

def gerrit_api(version = "3.5.0.1",
               plugin_api_sha1 = "9ae63c02455635de2d1a78865b0374a10f5e9465",
               acceptance_framework_sha1 = "2d33e5944f5a0b048ea355609040178e7385fdb3"):
    gerrit_api_version(
        name = "gerrit_api_version",
        version = version,
    )

    bouncycastle_repos()
    rules_python_repos()

    local_repository = version.endswith("-SNAPSHOT")

    maven_jar(
        name = "gerrit_plugin_api",
        artifact = "com.google.gerrit:gerrit-plugin-api:" + version,
        sha1 = "" if local_repository else plugin_api_sha1,
        repository = MAVEN_LOCAL if local_repository else MAVEN_CENTRAL,
    )
    maven_jar(
        name = "gerrit_acceptance_framework",
        artifact = "com.google.gerrit:gerrit-acceptance-framework:" + version,
        sha1 = "" if local_repository else acceptance_framework_sha1,
        repository = MAVEN_LOCAL if local_repository else MAVEN_CENTRAL,
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
