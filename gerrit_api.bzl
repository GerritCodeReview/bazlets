load("//tools:maven_jar.bzl", "maven_jar")
load("//:bouncycastle.bzl", "bouncycastle_repos")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.15-rc1"

def gerrit_api():
  bouncycastle_repos()

  maven_jar(
    name = 'gerrit_plugin_api',
    artifact = 'com.google.gerrit:gerrit-plugin-api:' + VER,
    sha1 = 'a448355a7fdfbace0e6e4f449c9a37aaa3a889f9',
  )
  maven_jar(
    name = 'gerrit_plugin_gwtui',
    artifact = 'com.google.gerrit:gerrit-plugin-gwtui:' + VER,
    sha1 = 'd2412bc6048294d2a3a5567d45788692631baa1a',
  )
  maven_jar(
    name = 'gerrit_acceptance_framework',
    artifact = 'com.google.gerrit:gerrit-acceptance-framework:' + VER,
    sha1 = '0870c05eaefa99bbfd0a873095d880d6398d43b0',
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
