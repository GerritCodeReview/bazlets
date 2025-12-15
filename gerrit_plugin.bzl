"""
Build rules for plugins.
"""

load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load(
    "//tools:commons.bzl",
    _plugin_deps = "PLUGIN_DEPS",
    _plugin_deps_neverlink = "PLUGIN_DEPS_NEVERLINK",
    _plugin_test_deps = "PLUGIN_TEST_DEPS",
)
load("//tools:genrule2.bzl", "genrule2")
load("//tools:junit.bzl", "junit_tests")

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
        runtime_deps = [],
        manifest_entries = [],
        dir_name = None,
        target_suffix = "",
        deploy_env = [],
        **kwargs):
    """Builds a Gerrit plugin.

    Args:
      name: The name of the plugin.
      deps: List of additional dependencies for the plugin.
      provided_deps: List of dependencies that are provided by Gerrit and should not be bundled.
      srcs: List of Java source files for the plugin.
      resources: List of resource files to be included in the plugin JAR.
      resource_jars: List of JARs containing resources.
      runtime_deps: List of runtime dependencies.
      manifest_entries: List of additional lines to add to the plugin's manifest file.
      dir_name: The directory name for the plugin, used in stamping. Defaults to `name`.
      target_suffix: Suffix to append to the final plugin JAR name.
      deploy_env: Environment variables for the deploy JAR.
      **kwargs: Additional arguments passed to the underlying `java_library` and `java_binary` rules.

    This rule creates a deployable .jar file for a Gerrit plugin."""

    if not native.module_name():
        gerrit_api_neverlink = PLUGIN_DEPS_NEVERLINK
    elif (native.module_name() == "gerrit"):
        gerrit_api_neverlink = ["//plugins:plugin-lib-neverlink"]
    else:
        java_library(
            name = name + "-gerrit-api-neverlink",
            neverlink = 1,
            visibility = ["//visibility:public"],
            exports = ["@gerrit_plugin_deps//:com_google_gerrit_gerrit_plugin_api"],
        )
        gerrit_api_neverlink = [":" + name + "-gerrit-api-neverlink"]

    java_library(
        name = name + "__plugin",
        srcs = srcs,
        resources = resources,
        deps = provided_deps + deps + gerrit_api_neverlink,
        runtime_deps = runtime_deps,
        visibility = ["//visibility:public"],
        **kwargs
    )

    if not dir_name:
        dir_name = name

    java_binary(
        name = "%s__non_stamped" % name,
        deploy_manifest_lines = manifest_entries + ["Gerrit-ApiType: plugin"],
        main_class = "Dummy",
        runtime_deps = [
            ":%s__plugin" % name,
        ] + runtime_deps + resource_jars,
        deploy_env = deploy_env,
        visibility = ["//visibility:public"],
        **kwargs
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
            "echo \"Implementation-Version: $$GEN_VERSION\nGerrit-ApiVersion: $$API_VERSION\n$$(cat META-INF/MANIFEST.MF)\" > META-INF/MANIFEST.MF",
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

def gerrit_plugin_tests(
        name,
        srcs = [],
        deps = [],
        **kwargs):
    """Runs junit tests for a Gerrit plugin.

    Args:
      name: The name of the plugin.
      deps: List of additional dependencies for the plugin.
      srcs: List of Java source files for the plugin.
      **kwargs: Additional arguments passed to the underlying `junit_tests` rule.
    """

    if (native.module_name() == "gerrit"):
        gerrit_api_deps = [
            "//plugins:plugin-lib",
            "//java/com/google/gerrit/acceptance:lib",
        ]
    else:
        java_library(
            name = name + "-gerrit-test-api",
            visibility = ["//visibility:public"],
            exports = [
                "@gerrit_plugin_deps//:com_google_gerrit_gerrit_acceptance_framework",
                "@gerrit_plugin_deps//:com_google_gerrit_gerrit_plugin_api",
            ],
        )
        gerrit_api_deps = [":" + name + "-gerrit-test-api"]

    junit_tests(
        name = name,
        srcs = srcs,
        deps = deps + gerrit_api_deps,
        **kwargs
    )
