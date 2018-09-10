load("//tools:maven_jar.bzl", "maven_jar")
load("//:bouncycastle.bzl", "bouncycastle_repos")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.15.3"

def gerrit_api():
    bouncycastle_repos()

    maven_jar(
        name = "gerrit_plugin_api",
        artifact = "com.google.gerrit:gerrit-plugin-api:" + VER,
<<<<<<< HEAD
        sha1 = "ff44f3b4faa9d7b8845f68e3340b72d800958e7e",
=======
        sha1 = "2056c3cd210bc500940fa2629191c90b470ea0d1",
>>>>>>> stable-2.14
    )
    maven_jar(
        name = "gerrit_plugin_gwtui",
        artifact = "com.google.gerrit:gerrit-plugin-gwtui:" + VER,
<<<<<<< HEAD
        sha1 = "795c35ad561f4e78d5ac582e7d7d23bdc5363052",
=======
        sha1 = "dd3d650ddbeb9aba32781bc6124dbe9bc5b275c9",
>>>>>>> stable-2.14
        exclude = ["com/google/gwt/*"],
    )
    maven_jar(
        name = "gerrit_acceptance_framework",
        artifact = "com.google.gerrit:gerrit-acceptance-framework:" + VER,
<<<<<<< HEAD
        sha1 = "9b55aa8a1184ed9ffe4ac982e1ceb069249783f7",
=======
        sha1 = "790327f96485afabfa158a88aac7a59fde1591e8",
>>>>>>> stable-2.14
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
