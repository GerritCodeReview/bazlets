load("//:bouncycastle.bzl", "bouncycastle_repos")
load("//tools:maven_jar.bzl", "maven_jar")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VERSIONS = {
  "2.16.9": ["f650c16c8fdc4a7d76663f0bd720fe3055c0cbe1", "cd48eb229a72b4e8af4e975366af570ff0c8fc5a", "33516d850b4906e069046add77037a96e27e26ae"]
}

def gerrit_api(version):
    bouncycastle_repos()

    maven_jar(
        name = "gerrit_plugin_api",
        artifact = "com.google.gerrit:gerrit-plugin-api:" + version,
        sha1 = VERSIONS[version][0],
    )
    native.bind(
        name = "gerrit-plugin-api",
        actual = "@gerrit_plugin_api//jar",
    )
    native.bind(
        name = "gerrit-plugin-api-neverlink",
        actual = "@gerrit_plugin_api//jar:neverlink",
    )

    maven_jar(
        name = "gerrit_acceptance_framework",
        artifact = "com.google.gerrit:gerrit-acceptance-framework:" + version,
        sha1 = VERSIONS[version][1],
    )
    native.bind(
        name = "gerrit-acceptance-framework",
        actual = "@gerrit_acceptance_framework//jar",
    )
    native.bind(
        name = "gerrit-acceptance-framework-neverlink",
        actual = "@gerrit_acceptance_framework//jar:neverlink",
    )

    if not version.startswith("3."):
        maven_jar(
            name = "gerrit_plugin_gwtui",
            artifact = "com.google.gerrit:gerrit-plugin-gwtui:" + version,
            sha1 = VERSIONS[version][2],
            exclude = ["com/google/gwt/*"],
        )
        native.bind(
            name = "gerrit-plugin-gwtui",
            actual = "@gerrit_plugin_gwtui//jar",
        )
        native.bind(
            name = "gerrit-plugin-gwtui-neverlink",
            actual = "@gerrit_plugin_gwtui//jar:neverlink",
        )
