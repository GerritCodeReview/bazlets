load("//tools:maven_jar.bzl", "maven_jar", "MAVEN_LOCAL")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.14-SNAPSHOT"

def gerrit_api_maven_local():
  maven_jar(
   name = 'gerrit_plugin_api',
   artifact = 'com.google.gerrit:gerrit-plugin-api:' + VER,
   repository = MAVEN_LOCAL,
  )
  maven_jar(
    name = 'gerrit_plugin_gwtui',
    artifact = 'com.google.gerrit:gerrit-plugin-gwtui:' + VER,
    repository = MAVEN_LOCAL,
  )
  native.bind(
    name = 'gerrit-plugin-api',
    actual = '@gerrit_plugin_api//jar')
  native.bind(
    name = 'gerrit-plugin-gwtui',
    actual = '@gerrit_plugin_gwtui//jar')
  native.bind(
    name = 'gerrit-plugin-api-neverlink',
    actual = '@gerrit_plugin_api//jar:neverlink')
  native.bind(
    name = 'gerrit-plugin-gwtui-neverlink',
    actual = '@gerrit_plugin_gwtui//jar:neverlink')
