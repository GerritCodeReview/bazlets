load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load(
    "//tools:commons.bzl",
    _plugin_deps = "PLUGIN_DEPS",
    _plugin_deps_neverlink = "PLUGIN_DEPS_NEVERLINK",
    _plugin_test_deps = "PLUGIN_TEST_DEPS",
)
load("//tools:genrule2.bzl", "genrule2")
load(
    "//tools:gwt.bzl",
    "GWT_COMPILER_ARGS",
    "GWT_JVM_ARGS",
    "GWT_PLUGIN_DEPS_NEVERLINK",
    "GWT_TRANSITIVE_DEPS",
    "gwt_binary",
    _gwt_plugin_deps = "GWT_PLUGIN_DEPS",
)

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_plugin is rule for building Gerrit plugins using Bazel.
"""

GWT_PLUGIN_DEPS = _gwt_plugin_deps
PLUGIN_DEPS = _plugin_deps
PLUGIN_DEPS_NEVERLINK = _plugin_deps_neverlink
PLUGIN_TEST_DEPS = _plugin_test_deps

def gerrit_plugin(
        name,
        deps = [],
        provided_deps = [],
        srcs = [],
        gwt_module = [],
        resources = [],
        manifest_entries = [],
        dir_name = None,
        target_suffix = "",
        **kwargs):
    gwt_deps = []
    static_jars = []
    if gwt_module:
        static_jars = [":%s-static" % name]
        gwt_deps = GWT_PLUGIN_DEPS_NEVERLINK

    if not dir_name:
        dir_name = name

    java_library(
        name = name + "__plugin",
        srcs = srcs,
        resources = resources,
        deps = provided_deps + deps + gwt_deps + PLUGIN_DEPS_NEVERLINK,
        visibility = ["//visibility:public"],
        **kwargs
    )
    java_binary(
        name = "%s__non_stamped" % name,
        deploy_manifest_lines = manifest_entries + ["Gerrit-ApiType: plugin"],
        main_class = "Dummy",
        runtime_deps = [
            ":%s__plugin" % name,
        ] + static_jars,
        visibility = ["//visibility:public"],
    )

    if gwt_module:
        java_library(
            name = name + "__gwt_module",
            resources = depset(srcs + resources).to_list(),
            runtime_deps = deps + GWT_PLUGIN_DEPS,
            visibility = ["//visibility:public"],
        )
        genrule2(
            name = "%s-static" % name,
            cmd = " && ".join([
                "mkdir -p $$TMP/static",
                "unzip -qd $$TMP/static $(location %s__gwt_application)" % name,
                "cd $$TMP",
                "zip -qr $$ROOT/$@ .",
            ]),
            tools = [":%s__gwt_application" % name],
            outs = ["%s-static.jar" % name],
        )
        gwt_binary(
            name = name + "__gwt_application",
            module = [gwt_module],
            deps = GWT_PLUGIN_DEPS + GWT_TRANSITIVE_DEPS + [
                "//external:gwt-dev",
                "//external:gwt-user",
            ],
            module_deps = [":%s__gwt_module" % name],
            compiler_args = GWT_COMPILER_ARGS,
            jvm_args = GWT_JVM_ARGS,
        )

    native.genrule(
        name = name + "__gen_stamp_info",
        stamp = 1,
        cmd = "cat bazel-out/stable-status.txt | grep \"^STABLE_BUILD_%s_LABEL\" | awk '{print $$NF}' > $@" % dir_name.upper(),
        outs = ["%s__gen_stamp_info.txt" % name],
    )

    # TODO(davido): Remove manual merge of manifest file when this feature
    # request is implemented: https://github.com/bazelbuild/bazel/issues/2009
    genrule2(
        name = name + target_suffix,
        stamp = 1,
        srcs = ["%s__non_stamped_deploy.jar" % name],
        cmd = " && ".join([
            "GEN_VERSION=$$(cat $(location :%s__gen_stamp_info))" % name,
            "cd $$TMP",
            "unzip -q $$ROOT/$<",
            "echo \"Implementation-Version: $$GEN_VERSION\n$$(cat META-INF/MANIFEST.MF)\" > META-INF/MANIFEST.MF",
            "zip -qr $$ROOT/$@ .",
        ]),
        tools = [":%s__gen_stamp_info" % name],
        outs = ["%s%s.jar" % (name, target_suffix)],
        visibility = ["//visibility:public"],
    )
