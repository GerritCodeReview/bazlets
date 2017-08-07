load("//tools:genrule2.bzl", "genrule2")
load(
    "//tools:commons.bzl",
    "PLUGIN_DEPS",
    "PLUGIN_DEPS_NEVERLINK",
    "PLUGIN_TEST_DEPS",
)
load(
    "//tools:gwt.bzl",
    "GWT_PLUGIN_DEPS",
    "GWT_PLUGIN_DEPS_NEVERLINK",
    "GWT_TRANSITIVE_DEPS",
    "GWT_COMPILER_ARGS",
    "GWT_JVM_ARGS",
    "gwt_binary",
)

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_plugin is rule for building Gerrit plugins using Bazel.
"""

def gerrit_plugin(
    name,
    deps = [],
    provided_deps = [],
    srcs = [],
    gwt_module = [],
    resources = [],
    manifest_entries = [],
    plugin_deps_neverlink = PLUGIN_DEPS_NEVERLINK,
    gwt_plugin_deps = GWT_PLUGIN_DEPS,
    gwt_plugin_deps_neverlink = GWT_PLUGIN_DEPS_NEVERLINK,
    target_suffix = "",
    **kwargs):

  gwt_deps = []
  static_jars = []
  if not plugin_deps_neverlink:
    plugin_deps_neverlink = PLUGIN_DEPS_NEVERLINK
  if gwt_module:
    static_jars = [':%s-static' % name]
    gwt_deps = gwt_plugin_deps

  native.java_library(
    name = name + '__plugin',
    srcs = srcs,
    resources = resources,
    deps = provided_deps + deps + gwt_deps + plugin_deps_neverlink,
    visibility = ['//visibility:public'],
    **kwargs
  )

  native.java_binary(
    name = '%s__non_stamped' % name,
    deploy_manifest_lines = manifest_entries + ["Gerrit-ApiType: plugin"],
    main_class = 'Dummy',
    runtime_deps = [
      ':%s__plugin' % name,
    ] + static_jars,
    visibility = ['//visibility:public'],
  )

  if gwt_module:
    native.java_library(
      name = name + '__gwt_module',
      resources = list(set(srcs + resources)),
      runtime_deps = deps + gwt_plugin_deps,
      visibility = ['//visibility:public'],
    )
    genrule2(
      name = '%s-static' % name,
      cmd = ' && '.join([
        'mkdir -p $$TMP/static',
        'unzip -qd $$TMP/static $(location %s__gwt_application)' % name,
        'cd $$TMP',
        'zip -qr $$ROOT/$@ .']),
      tools = [':%s__gwt_application' % name],
      outs = ['%s-static.jar' % name],
    )
    gwt_binary(
      name = name + '__gwt_application',
      module = [gwt_module],
      deps = gwt_plugin_deps + GWT_TRANSITIVE_DEPS + [
        '//external:gwt-dev',
        '//external:gwt-user',
      ],
      module_deps = [':%s__gwt_module' % name],
      compiler_args = GWT_COMPILER_ARGS,
      jvm_args = GWT_JVM_ARGS,
    )

  # TODO(davido): Remove manual merge of manifest file when this feature
  # request is implemented: https://github.com/bazelbuild/bazel/issues/2009
  genrule2(
    name = name + target_suffix,
    stamp = 1,
    srcs = ['%s__non_stamped_deploy.jar' % name],
    cmd = " && ".join([
      "GEN_VERSION=$$(cat bazel-out/stable-status.txt | grep %s | cut -d ' ' -f 2)" % name.upper(),
      "cd $$TMP",
      "unzip -q $$ROOT/$<",
      "echo \"Implementation-Version: $$GEN_VERSION\n$$(cat META-INF/MANIFEST.MF)\" > META-INF/MANIFEST.MF",
      "zip -qr $$ROOT/$@ ."]),
    outs = ['%s%s.jar' % (name, target_suffix)],
    visibility = ['//visibility:public'],
  )
