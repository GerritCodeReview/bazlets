load("//tools:genrule2.bzl", "genrule2")
load("//tools:commons.bzl", "PLUGIN_DEPS_NEVERLINK")
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
    srcs = [],
    gwt_module = [],
    resources = [],
    manifest_entries = [],
    **kwargs):

  gwt_deps = []
  static_jars = []
  if gwt_module:
    static_jars = [':%s-static' % name]
    gwt_deps = GWT_PLUGIN_DEPS_NEVERLINK

  native.java_library(
    name = name + '__plugin',
    srcs = srcs,
    resources = resources,
    deps = deps + gwt_deps + PLUGIN_DEPS_NEVERLINK,
    visibility = ['//visibility:public'],
    **kwargs
  )

  native.java_binary(
    name = '%s__non_stamped' % name,
    deploy_manifest_lines = manifest_entries + [
      "Gerrit-ApiType: plugin",
      "Implementation-Vendor: Gerrit Code Review",
    ],
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
      runtime_deps = deps + GWT_PLUGIN_DEPS,
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
      deps = GWT_PLUGIN_DEPS + GWT_TRANSITIVE_DEPS + ['//external:gwt-dev'],
      module_deps = [':%s__gwt_module' % name],
      compiler_args = GWT_COMPILER_ARGS,
      jvm_args = GWT_JVM_ARGS,
    )

  # TODO(davido): Remove manual merge of manifest file when this feature
  # request is implemented: https://github.com/bazelbuild/bazel/issues/2009
  genrule2(
    name = name,
    stamp = 1,
    srcs = ['%s__non_stamped_deploy.jar' % name],
    cmd = " && ".join([
      "GEN_VERSION=$$(cat bazel-out/stable-status.txt | grep %s | cut -d ' ' -f 2)" % name.upper(),
      "cd $$TMP",
      "unzip -q $$ROOT/$<",
      "echo \"Implementation-Version: $$GEN_VERSION\n$$(cat META-INF/MANIFEST.MF)\" > META-INF/MANIFEST.MF",
      "zip -qr $$ROOT/$@ ."]),
    outs = ['%s.jar' % name],
    visibility = ['//visibility:public'],
  )
