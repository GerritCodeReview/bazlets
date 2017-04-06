load("//tools:maven_jar.bzl", "maven_jar")
load("//:bouncycastle.bzl", "bouncycastle_repository")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api is rule for fetching Gerrit plugin API using Bazel.
"""

VER = "2.13.2"

def gerrit_api():
  bouncycastle_repository()

  maven_jar(
   name = 'gerrit_plugin_api',
   artifact = 'com.google.gerrit:gerrit-plugin-api:' + VER,
   sha1 = '3cdeb17c2b0f945e71135ef6abe5a1db59b9d313',
  )
  maven_jar(
    name = 'gerrit_plugin_gwtui',
    artifact = 'com.google.gerrit:gerrit-plugin-gwtui:' + VER,
    sha1 = 'f89723a589e42e7e593266ab3eb2e57b960be50a',
  )
  maven_jar(
    name = 'gerrit_acceptance_framework',
    artifact = 'com.google.gerrit:gerrit-acceptance-framework:' + VER,
    sha1 = '45331fca49510f9985eee263a845d38d044aa175',
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
