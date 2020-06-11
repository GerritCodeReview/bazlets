load("//:bouncycastle.bzl", "bouncycastle_repos")
load("//:rules_python.bzl", "rules_python_repos")
load("//tools:maven_jar.bzl", "MAVEN_LOCAL", "MAVEN_CENTRAL", "maven_jar")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

GERRIT_API_VERSION="3.0.10"

def gerrit_api(local = "automatic"):
    bouncycastle_repos()
    rules_python_repos()

    if local == "automatic":
        local = GERRIT_API_VERSION.endswith("-SNAPSHOT")

    maven_jar(
        name = "gerrit_plugin_api",
        artifact = "com.google.gerrit:gerrit-plugin-api:" + GERRIT_API_VERSION,
        sha1 = "" if local else "90df648d9ef9e1a953e253972d9922fc1b753f83",
        repository = MAVEN_LOCAL if local else MAVEN_CENTRAL,
    )
    maven_jar(
        name = "gerrit_acceptance_framework",
        artifact = "com.google.gerrit:gerrit-acceptance-framework:" + GERRIT_API_VERSION,
        sha1 = "" if local else "9c30ee281fa9016d460d16dd08a87ef16cedbf84",
        repository = MAVEN_LOCAL if local else MAVEN_CENTRAL,
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
