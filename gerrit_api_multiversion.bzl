load("//tools:maven_jar.bzl", "maven_jar", "MAVEN_LOCAL")
load("//:bouncycastle.bzl", "bouncycastle_repos")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_api_multiversion is rule for fetching Gerrit plugin API using Bazel.
"""

VER_2_14_1 = "2.14.1"
VER_2_14_2 = "2.14.2"
VER_SNAPSHOT = "2.15-SNAPSHOT"

def gerrit_api_multiversion():
  bouncycastle_repos()
  api_2_14_1()
  api_2_14_2()
  # Add here newer released api version
  api_snapshot_as_default()

def api_2_14_1():
  maven_jar(
   name = "gerrit_plugin_api_" + VER_2_14_1,
   artifact = "com.google.gerrit:gerrit-plugin-api:" + VER_2_14_1,
   sha1 = "ba69f1c1875a4933177d81fabb39a5675f6ba818",
  )
  maven_jar(
    name = "gerrit_plugin_gwtui_" + VER_2_14_1,
    artifact = "com.google.gerrit:gerrit-plugin-gwtui:" + VER_2_14_1,
    sha1 = "863651931ef5c84cb50eb16d5e6123a691a2c23d",
  )
  maven_jar(
    name = "gerrit_acceptance_framework_" + VER_2_14_1,
    artifact = "com.google.gerrit:gerrit-acceptance-framework:" + VER_2_14_1,
    sha1 = "3e73e553ee2e76022810991519150c1b772c8fb6",
  )
  native.bind(
    name = "gerrit-plugin-api_" + VER_2_14_1,
    actual = "@gerrit_plugin_api_%s//jar" % VER_2_14_1)
  native.bind(
    name = "gerrit-plugin-gwtui_" + VER_2_14_1,
    actual = "@gerrit_plugin_gwtui_%s//jar" % VER_2_14_1)
  native.bind(
    name = "gerrit-acceptance-framework_" + VER_2_14_1,
    actual = "@gerrit_acceptance_framework_%s//jar" % VER_2_14_1)
  native.bind(
    name = "gerrit-plugin-api-neverlink_" + VER_2_14_1,
    actual = "@gerrit_plugin_api_%s//jar:neverlink" % VER_2_14_1)
  native.bind(
    name = "gerrit-plugin-gwtui-neverlink_" + VER_2_14_1,
    actual = "@gerrit_plugin_gwtui_%s//jar:neverlink" % VER_2_14_1)
  native.bind(
    name = "gerrit-acceptance-framework-neverlink_" + VER_2_14_1,
    actual = "@gerrit_acceptance_framework_%s//jar:neverlink" % VER_2_14_1)

def api_2_14_2():
  maven_jar(
   name = "gerrit_plugin_api_" + VER_2_14_2,
   artifact = "com.google.gerrit:gerrit-plugin-api:" + VER_2_14_2,
   sha1 = "f2aa0f6852a838d8d5b0d517e4f8e164cfd764c1",
  )
  maven_jar(
    name = "gerrit_plugin_gwtui_" + VER_2_14_2,
    artifact = "com.google.gerrit:gerrit-plugin-gwtui:" + VER_2_14_2,
    sha1 = "e11be9b6061c2854c43660829c1a858982b0e706",
  )
  maven_jar(
    name = "gerrit_acceptance_framework_" + VER_2_14_2,
    artifact = "com.google.gerrit:gerrit-acceptance-framework:" + VER_2_14_2,
    sha1 = "8356f448b40c137e0c172f475adcb679cb807f00",
  )
  native.bind(
    name = "gerrit-plugin-api_" + VER_2_14_2,
    actual = "@gerrit_plugin_api_%s//jar" % VER_2_14_2)
  native.bind(
    name = "gerrit-plugin-gwtui_" + VER_2_14_2,
    actual = "@gerrit_plugin_gwtui_%s//jar" % VER_2_14_2)
  native.bind(
    name = "gerrit-acceptance-framework_" + VER_2_14_2,
    actual = "@gerrit_acceptance_framework_%s//jar" % VER_2_14_2)
  native.bind(
    name = "gerrit-plugin-api-neverlink_" + VER_2_14_2,
    actual = "@gerrit_plugin_api_%s//jar:neverlink" % VER_2_14_2)
  native.bind(
    name = "gerrit-plugin-gwtui-neverlink_" + VER_2_14_2,
    actual = "@gerrit_plugin_gwtui_%s//jar:neverlink" % VER_2_14_2)
  native.bind(
    name = "gerrit-acceptance-framework-neverlink_" + VER_2_14_2,
    actual = "@gerrit_acceptance_framework_%s//jar:neverlink" % VER_2_14_2)

def api_snapshot_as_default():
  maven_jar(
   name = 'gerrit_plugin_api',
   artifact = 'com.google.gerrit:gerrit-plugin-api:' + VER_SNAPSHOT,
   repository = MAVEN_LOCAL,
  )
  maven_jar(
    name = 'gerrit_plugin_gwtui',
    artifact = 'com.google.gerrit:gerrit-plugin-gwtui:' + VER_SNAPSHOT,
    repository = MAVEN_LOCAL,
  )
  maven_jar(
    name = 'gerrit_acceptance_framework',
    artifact = 'com.google.gerrit:gerrit-acceptance-framework:' + VER_SNAPSHOT,
    repository = MAVEN_LOCAL,
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
