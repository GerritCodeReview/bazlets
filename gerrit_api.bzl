load("//tools:maven_jar.bzl", "maven_jar")
load("//:bouncycastle.bzl", "bouncycastle_repos")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.15"

def gerrit_api():
  bouncycastle_repos()

  maven_jar(
    name = 'gerrit_plugin_api',
    artifact = 'com.google.gerrit:gerrit-plugin-api:' + VER,
    sha1 = '6aeae2c4071e1c1015191b703f40bad123f26d95',
  )
  maven_jar(
    name = 'gerrit_plugin_gwtui',
    artifact = 'com.google.gerrit:gerrit-plugin-gwtui:' + VER,
    sha1 = '7409de8275152d070c2e8cbbd5c2b50a2166d7cc',
    exclude = ['com/google/gwt/*'],
  )
  maven_jar(
    name = 'gerrit_acceptance_framework',
    artifact = 'com.google.gerrit:gerrit-acceptance-framework:' + VER,
    sha1 = '39886fe226d5c74d485571f43e264a0b77ed2021',
  )
  native.bind(
    name = 'gerrit-plugin-api',
    actual = '@gerrit_plugin_api//jar')
  native.bind(
    name = 'gerrit-plugin-gwtui',
    actual = '@gerrit_plugin_gwtui//jar')
  native.bind(
    name = 'gerrit-acceptance-framework',
    actual = '@gerrit_acceptance_framework//jar')
  native.bind(
    name = 'gerrit-plugin-api-neverlink',
    actual = '@gerrit_plugin_api//jar:neverlink')
  native.bind(
    name = 'gerrit-plugin-gwtui-neverlink',
    actual = '@gerrit_plugin_gwtui//jar:neverlink')
  native.bind(
    name = 'gerrit-acceptance-framework-neverlink',
    actual = '@gerrit_acceptance_framework//jar:neverlink')
