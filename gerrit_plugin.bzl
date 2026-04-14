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
load("//tools:in_gerrit_tree.bzl", "in_gerrit_tree_enabled")
load("//tools:runtime_jars_allowlist.bzl", "runtime_jars_allowlist_test")
load("//tools:runtime_jars_overlap.bzl", "runtime_jars_overlap_test")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_plugin is rule for building Gerrit plugins using Bazel.
"""

PLUGIN_DEPS = _plugin_deps
PLUGIN_DEPS_NEVERLINK = _plugin_deps_neverlink
PLUGIN_TEST_DEPS = _plugin_test_deps

def gerrit_api_neverlink(name):
    """Return the correct Gerrit API neverlink dependency for the current build mode."""
    if not native.module_name():
        # Gerrit and/or plugin does not use bazel modules yet; use Gerrit API from
        # maven repository as defined in gerrit_api.bzl
        # TODO(thomas): Remove after migration to Bazel modules is complete
        return PLUGIN_DEPS_NEVERLINK
    elif native.module_name() == "gerrit":
        # In-tree build, i.e. Gerrit is the main module; use Gerrit API from Gerrit
        # source tree
        return ["//plugins:plugin-lib-neverlink"]
    else:
        # Standalone build; use Gerrit API from maven repository as defined in
        # plugin's module
        java_library(
            name = name + "-gerrit-api-neverlink",
            neverlink = 1,
            visibility = ["//visibility:public"],
            exports = ["@external_plugin_deps//:com_google_gerrit_gerrit_plugin_api"],
        )
        return [":" + name + "-gerrit-api-neverlink"]

def gerrit_api():
    """Return the correct Gerrit API dependency for the current build mode."""
    if not native.module_name():
        # Gerrit and/or plugin does not use bazel modules yet; use Gerrit API from
        # maven repository as defined in gerrit_api.bzl
        # TODO(thomas): Remove after migration to Bazel modules is complete
        return PLUGIN_DEPS
    elif native.module_name() == "gerrit":
        # In-tree build, i.e. Gerrit is the main module; use Gerrit API from Gerrit
        # source tree
        return ["//plugins:plugin-lib"]
    else:
        # Standalone build; use Gerrit API from maven repository as defined in
        # plugin's module
        return ["@external_plugin_deps//:com_google_gerrit_gerrit_plugin_api"]

def gerrit_acceptance_framework():
    """
    Return the correct Gerrit Acceptance Framework dependency for the current
    build mode.
    """
    if not native.module_name():
        # Gerrit and/or plugin does not use bazel modules yet; use Gerrit API from
        # maven repository as defined in gerrit_api.bzl
        # TODO(thomas): Remove after migration to Bazel modules is complete
        return PLUGIN_TEST_DEPS
    elif native.module_name() == "gerrit":
        # In-tree build, i.e. Gerrit is the main module; use Gerrit API from Gerrit
        # source tree
        return ["//java/com/google/gerrit/acceptance:lib"]
    else:
        # Standalone build; use Gerrit API from maven repository as defined in
        # plugin's module
        return ["@external_plugin_deps//:com_google_gerrit_gerrit_acceptance_framework"]

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

    This rule creates a deployable .jar file for a Gerrit plugin.
    """

    java_library(
        name = name + "__plugin",
        srcs = srcs,
        resources = resources,
        deps = provided_deps + deps + gerrit_api_neverlink(name),
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
            "unzip -qo $$ROOT/$< -x 'META-INF/LICENSE' 'META-INF/LICENSE.txt' 'META-INF/NOTICE' 'META-INF/NOTICE.txt' 'META-INF/license' 'META-INF/license/*' 'META-INF/notice' 'META-INF/notice/*'",
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
        plugin = "",
        exports = [],
        **kwargs):
    """Runs junit tests for a Gerrit plugin.

    Args:
      name: The name of the plugin.
      deps: List of additional dependencies for the plugin.
      srcs: List of Java source files for the plugin.
      plugin: The name of the plugin to test. Only required, if exports is specified.
      exports: List of targets to export for in-tree testing. Must be used together
        with `plugin` argument. Targets will also be added as dependencies to
        the test target created by this rule.
      **kwargs: Additional arguments passed to the underlying `junit_tests` rule.
    """

    if exports:
        if not plugin:
            fail("plugin argument must be set when exports are provided")
        java_library(
            name = plugin + "__plugin_test_deps",
            testonly = True,
            visibility = ["//visibility:public"],
            exports = exports,
        )
        deps = deps + [plugin + "__plugin_test_deps"]

    junit_tests(
        name = name,
        srcs = srcs,
        deps = deps + gerrit_api() + gerrit_acceptance_framework(),
        **kwargs
    )

def gerrit_plugin_test_util(
        name,
        srcs = [],
        deps = [],
        **kwargs):
    """Creates a test utility library for a Gerrit plugin.

     This is intended for code that is only used by tests and should not be
     included in the plugin JAR.

    Args:
      name: The name of the test utility library.
      deps: List of additional dependencies for the test utility library.
      srcs: List of Java source files for the test utility library.
      **kwargs: Additional arguments passed to the underlying `java_library` rule.
    """

    java_library(
        name = name,
        testonly = True,
        srcs = srcs,
        deps = deps + gerrit_api_neverlink(name) + gerrit_acceptance_framework(),
        **kwargs
    )

def gerrit_plugin_dependency_tests(
        plugin,
        name = "dependency_tests",
        allowlist = None,
        overlap_against = None):
    """Generates runtime JAR safety tests for a Gerrit plugin.

    Targets the `:{plugin}__plugin` library created by `gerrit_plugin()`, so
    the `plugin` argument must match the `name` passed to `gerrit_plugin()`.

    Always creates two test targets:
      - `{plugin}_dependency_allowlist_test`: verifies the set of bundled
        third-party JARs exactly matches the allowlist.
      - `{plugin}_dependency_overlap_test`: verifies the plugin does not bundle
        JARs already shipped by Gerrit at runtime (automatically skipped in
        standalone plugin workspaces; see `in_gerrit_tree_enabled()`).

    Both targets are discovered by `bazelisk test //plugins/{plugin}/...`.

    Args:
      plugin: Plugin name as passed to `gerrit_plugin()`. Used to derive the
              checked target `:{plugin}__plugin` and to name the generated
              test targets.
      name: Unused; accepted for API compatibility. Defaults to
            "dependency_tests".
      allowlist: Label of a text file listing the expected bundled third-party
                 JAR IDs, one per line. Defaults to
                 `:{plugin}_third_party_runtime_jars.allowlist.txt`.
                 Refresh it by building the corresponding manifest target and
                 copying its output over the allowlist file.
      overlap_against: Label of a JAR-ID manifest to check for overlap (e.g.
                       the Gerrit WAR's `//:headless.war.jars.txt`). Defaults
                       to `//:headless.war.jars.txt`.

    Example:
      load(
          "@com_googlesource_gerrit_bazlets//:gerrit_plugin.bzl",
          "gerrit_plugin",
          "gerrit_plugin_dependency_tests",
      )

      gerrit_plugin(
          name = "my-plugin",
          srcs = glob(["src/main/java/**/*.java"]),
          manifest_entries = [
              "Gerrit-PluginName: my-plugin",
              "Gerrit-Module: com.example.MyModule",
          ],
      )

      gerrit_plugin_dependency_tests(
          plugin = "my-plugin",
          # Optional: supply a custom allowlist or overlap manifest.
          # allowlist = ":my_plugin_third_party_runtime_jars.allowlist.txt",
          # overlap_against = "//:headless.war.jars.txt",
      )
    """
    plugin_target = ":%s__plugin" % plugin

    if not allowlist:
        allowlist = ":%s_third_party_runtime_jars.allowlist.txt" % plugin

    runtime_jars_allowlist_test(
        name = plugin + "_dependency_allowlist_test",
        target = plugin_target,
        allowlist = allowlist,
    )

    if not overlap_against:
        overlap_against = "//:headless.war.jars.txt"

    runtime_jars_overlap_test(
        name = plugin + "_dependency_overlap_test",
        target = plugin_target,
        against = overlap_against,
        target_compatible_with = in_gerrit_tree_enabled(),
    )

    native.test_suite(
        name = name,
        tests = [
            ":" + plugin + "_dependency_allowlist_test",
            ":" + plugin + "_dependency_overlap_test",
        ],
    )
