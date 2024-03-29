load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load(
    "//tools:commons.bzl",
    _plugin_deps = "PLUGIN_DEPS",
    _plugin_deps_neverlink = "PLUGIN_DEPS_NEVERLINK",
    _plugin_test_deps = "PLUGIN_TEST_DEPS",
)
load("//tools:genrule2.bzl", "genrule2")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_plugin is rule for building Gerrit plugins using Bazel.
"""

PLUGIN_DEPS = _plugin_deps
PLUGIN_DEPS_NEVERLINK = _plugin_deps_neverlink
PLUGIN_TEST_DEPS = _plugin_test_deps

def gerrit_plugin(
        name,
        deps = [],
        provided_deps = [],
        srcs = [],
        resources = [],
        resource_jars = [],
        manifest_entries = [],
        dir_name = None,
        target_suffix = "",
        **kwargs):
    if not dir_name:
        dir_name = name

    java_library(
        name = name + "__plugin",
        srcs = srcs,
        resources = resources,
        deps = provided_deps + deps + PLUGIN_DEPS_NEVERLINK,
        visibility = ["//visibility:public"],
        **kwargs
    )
    java_binary(
        name = "%s__non_stamped" % name,
        deploy_manifest_lines = manifest_entries + ["Gerrit-ApiType: plugin"],
        main_class = "Dummy",
        runtime_deps = [
            ":%s__plugin" % name,
        ] + resource_jars,
        visibility = ["//visibility:public"],
    )

    native.genrule(
        name = name + "__gen_stamp_info",
        stamp = 1,
        cmd = "cat bazel-out/stable-status.txt | grep \"^STABLE_BUILD_%s_LABEL\" | awk '{print $$NF}' > $@" % dir_name.upper(),
        outs = ["%s__gen_stamp_info.txt" % name],
    )

    # TODO(davido): Remove manual merge of manifest file when this feature
    # request is implemented: https://github.com/bazelbuild/bazel/issues/2009
    # TODO(davido): Remove manual touch command when this issue is resolved:
    # https://github.com/bazelbuild/bazel/issues/10789
    genrule2(
        name = name + target_suffix,
        stamp = 1,
        srcs = ["%s__non_stamped_deploy.jar" % name],
        cmd = " && ".join([
            "TZ=UTC",
            "export TZ",
            "GEN_VERSION=$$(cat $(location :%s__gen_stamp_info))" % name,
            "API_VERSION=$$(cat $(location @gerrit_api_version//:version.txt))",
            "cd $$TMP",
            "unzip -q $$ROOT/$<",
            "echo \"Implementation-Version: $$GEN_VERSION\n$$API_VERSION\n$$(cat META-INF/MANIFEST.MF)\" > META-INF/MANIFEST.MF",
            "find . -exec touch '{}' ';'",
            "zip -Xqr $$ROOT/$@ .",
        ]),
        tools = [
            ":%s__gen_stamp_info" % name,
            "@gerrit_api_version//:version.txt",
        ],
        outs = ["%s%s.jar" % (name, target_suffix)],
        visibility = ["//visibility:public"],
    )
