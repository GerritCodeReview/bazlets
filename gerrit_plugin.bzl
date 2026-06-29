"""
Build rules for plugins.
"""

load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load("@rules_jvm_external//:defs.bzl", "artifact")
load(
    "//tools:commons.bzl",
    _plugin_deps = "PLUGIN_DEPS",
    _plugin_deps_neverlink = "PLUGIN_DEPS_NEVERLINK",
    _plugin_test_deps = "PLUGIN_TEST_DEPS",
)
load("//tools:flavour.bzl", "ee10_flavour_jar")
load("//tools:genrule2.bzl", "genrule2")
load("//tools:in_gerrit_tree.bzl", "in_gerrit_tree_enabled")
load("//tools:junit.bzl", "junit_tests")
load("//tools:runtime_jars_allowlist.bzl", "runtime_jars_allowlist_test")
load("//tools:runtime_jars_overlap.bzl", "runtime_jars_overlap_test")
load("//tools:servlet_transform.bzl", "transform_srcjar")

"""Bazel rule for building [Gerrit Code Review](https://www.gerritcodereview.com/)
gerrit_plugin is rule for building Gerrit plugins using Bazel.
"""

PLUGIN_DEPS = _plugin_deps
PLUGIN_DEPS_NEVERLINK = _plugin_deps_neverlink
PLUGIN_TEST_DEPS = _plugin_test_deps

def gerrit_api_neverlink(name, flavour = None):
    """Return the correct Gerrit API neverlink dependency for the current build mode.

    When flavour == "ee10" the jakarta.servlet plugin API is selected instead of
    the default javax.servlet one. In-tree (Gerrit is the main module) the
    flavour-aware `//plugins:plugin-lib-neverlink` already flips to jakarta under
    `--@com_googlesource_gerrit_bazlets//flags:flavour=ee10`, so no per-flavour
    label is needed there. Standalone
    builds resolve the suffixed `..._gerrit_plugin_api_ee10` artifact, which the
    plugin's own module must declare in its `external_plugin_deps` maven.install.
    """
    if not native.module_name():
        # Gerrit and/or plugin does not use bazel modules yet; use Gerrit API from
        # maven repository as defined in gerrit_api.bzl
        # TODO(thomas): Remove after migration to Bazel modules is complete
        return PLUGIN_DEPS_NEVERLINK
    elif native.module_name() == "gerrit":
        # In-tree build, i.e. Gerrit is the main module; use Gerrit API from Gerrit
        # source tree. This target is flavour-aware via select() on //tools:ee10;
        # the ee10 jar is produced by the gerrit_plugin(flavour = "ee10") target,
        # which self-transitions the flavour (no command-line flag needed).
        return ["//plugins:plugin-lib-neverlink"]
    else:
        # Standalone build; use Gerrit API from maven repository as defined in
        # plugin's module.
        api = "com_google_gerrit_gerrit_plugin_api"
        if flavour == "ee10":
            api = "com_google_gerrit_gerrit_plugin_api_ee10"
        java_library(
            name = name + "-gerrit-api-neverlink",
            neverlink = 1,
            visibility = ["//visibility:public"],
            exports = ["@external_plugin_deps//:" + api],
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

def _artifacts(coords, repository_name):
    """Convert Maven coordinates to Bazel labels in the given external repo.

    Args:
      coords: List of Maven coordinates, for example
        `["com.github.scribejava:scribejava-core"]`.
      repository_name: Name of the rules_jvm_external repository that exports
        the generated labels, for example `"oauth_plugin_deps"`.

    Returns:
      List of Bazel labels corresponding to the given Maven coordinates.
    """
    return [artifact(c, repository_name = repository_name) for c in coords]

def _plugin_test_deps_name(plugin):
    return plugin + "__plugin_test_deps"

def gerrit_plugin(
        name = None,
        plugin = None,
        deps = [],
        ext_deps = [],
        ext_repo = None,
        srcs = [],
        resources = [],
        resource_jars = [],
        runtime_deps = [],
        manifest_entries = [],
        dir_name = None,
        license = None,
        target_suffix = "",
        flavour = None,
        flavour_src_prefix = "src/main/java/",
        deploy_env = [],
        dependency_test_name = None,
        dependency_test_allowlist = None,
        dependency_test_overlap_against = None,
        **kwargs):
    """Builds a Gerrit plugin.

    Args:
      name: The name of the plugin target.
      plugin: Backward-compatible alias for `name`.
      deps: List of additional Bazel dependencies for the plugin.
      ext_deps: List of Maven coordinates for external dependencies.
      ext_repo: Name of the external repository generated by rules_jvm_external.
        Defaults to `<name>_plugin_deps`.
      srcs: List of Java source files for the plugin.
      resources: List of resource files to be included in the plugin JAR.
      resource_jars: List of JARs containing resources.
      runtime_deps: List of runtime Bazel dependencies.
      manifest_entries: List of additional lines to add to the plugin's manifest file.
      dir_name: The directory name for the plugin, used in stamping. Defaults to `name`.
      license: Optional plugin-owned license file to package as `META-INF/LICENSE`.
      target_suffix: Suffix to append to the final plugin JAR name.
      flavour: Servlet flavour of the produced plugin: `None`/`"ee8"` (default,
        javax.servlet) or `"ee10"` (jakarta.servlet). When `"ee10"`, the plugin
        sources are rewritten javax->jakarta by the shared `to_jakarta` transform,
        a `Gerrit-Flavour: ee10` manifest entry is injected, and the jakarta
        Gerrit plugin API is selected. Build the ee10 target with a distinct
        `name` (e.g. `<plugin>-ee10`) and `dir_name = "<plugin>"`; the ee8 default
        target is left unchanged. See `tools/servlet_transform.bzl`.
      flavour_src_prefix: Path prefix stripped from each source when building the
        ee10 srcjar. Defaults to `"src/main/java/"` (the standard plugin layout).
      deploy_env: List of java_binary targets representing the runtime/deployment
        environment that will load this plugin. Dependencies shared with these
        targets are excluded from this binary's runtime classpath and deploy jar.
      dependency_test_name: Name of the generated dependency test suite.
        Defaults to `<plugin>_dependency_tests`.
      dependency_test_allowlist: Optional allowlist passed to
        `gerrit_plugin_dependency_tests()`.
      dependency_test_overlap_against: Optional overlap manifest passed to
        `gerrit_plugin_dependency_tests()`.
      **kwargs: Additional arguments passed to the underlying `java_library` and `java_binary` rules.

    This rule creates a deployable .jar file for a Gerrit plugin."""

    if name == None:
        name = plugin
    elif plugin != None and plugin != name:
        fail("gerrit_plugin: `name` and `plugin` must match if both are set")

    if name == None:
        fail("gerrit_plugin: one of `name` or `plugin` must be set")

    if flavour not in (None, "ee8", "ee10"):
        fail("gerrit_plugin: `flavour` must be one of None, \"ee8\", \"ee10\"")

    if ext_repo == None:
        ext_repo = name + "_plugin_deps"

    deps = deps + _artifacts(ext_deps, ext_repo)

    # EE10 (jakarta.servlet) flavour: rewrite the plugin's own servlet/Jetty
    # imports javax->jakarta via the shared transform, compile against the
    # jakarta plugin API (selected in gerrit_api_neverlink), and stamp the jar
    # with a `Gerrit-Flavour: ee10` manifest marker (so a future loader-side
    # guard can reject a flavour mismatch; that runtime check is not implemented
    # yet). The canonical (ee8) sources are untouched; this is a parallel target
    # with a distinct name.
    if flavour == "ee10":
        srcjar = name + "__" + flavour + "_srcjar"
        transform_srcjar(
            name = srcjar,
            direction = "to_jakarta",
            sources = srcs,
            src_prefix = flavour_src_prefix,
        )
        srcs = [":" + srcjar]
        manifest_entries = manifest_entries + ["Gerrit-Flavour: ee10"]

    java_library(
        name = name + "__plugin",
        srcs = srcs,
        resources = resources,
        deps = deps + gerrit_api_neverlink(name, flavour),
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
    license_tools = [license] if license else []
    copy_license_cmd = (
        "mkdir -p META-INF && cp -f $$ROOT/$(location %s) META-INF/LICENSE" % license if license else "true"
    )

    EXCLUDES = " ".join([
        "'META-INF/%s'" % p
        for p in [
            "LICENSE",
            "LICENSE.txt",
            "NOTICE",
            "NOTICE.txt",
            "license",
            "license/*",
            "notice",
            "notice/*",
        ]
    ])
    # For the EE10 flavour the public target is an ee10_flavour_jar wrapper that
    # builds the (transform-fed) jar under a flavour=ee10 transition, so the
    # plugin self-selects the jakarta config. The genrule that assembles the jar
    # therefore gets an internal name and the wrapper takes the public one.
    final_target = name + target_suffix
    jar_target = final_target + "__flavour_jar" if flavour == "ee10" else final_target

    genrule2(
        name = jar_target,
        stamp = 1,
        srcs = ["%s__non_stamped_deploy.jar" % name],
        cmd = " && ".join([
            "TZ=UTC",
            "export TZ",
            "GEN_VERSION=$$(cat $(location :%s__gen_stamp_info))" % name,
            "API_VERSION=$$(cat $(location @gerrit_api_version//:version.txt))",
            "cd $$TMP",
            "unzip -qo $$ROOT/$< -x " + EXCLUDES + " 2>/dev/null",
            copy_license_cmd,
            "echo \"Implementation-Version: $$GEN_VERSION\nGerrit-ApiVersion: $$API_VERSION\n$$(cat META-INF/MANIFEST.MF)\" > META-INF/MANIFEST.MF",
            "find . -exec touch '{}' ';'",
            "zip -Xqr $$ROOT/$@ .",
        ]),
        tools = [
            ":%s__gen_stamp_info" % name,
            "@gerrit_api_version//:version.txt",
        ] + license_tools,
        outs = ["%s.jar" % jar_target],
        visibility = ["//visibility:public"],
    )

    if flavour == "ee10":
        ee10_flavour_jar(
            name = final_target,
            actual = ":" + jar_target,
            visibility = ["//visibility:public"],
        )

    if ext_deps and plugin:
        if dependency_test_name == None:
            dependency_test_name = plugin + "_dependency_tests"
        gerrit_plugin_dependency_tests(
            plugin = plugin,
            name = dependency_test_name,
            allowlist = dependency_test_allowlist,
            overlap_against = dependency_test_overlap_against,
        )

def gerrit_plugin_ext_test_deps(
        plugin,
        ext_deps,
        ext_repo = None,
        name = None,
        tags = None):
    """Creates the Eclipse classpath helper target for plugin test deps.

    Args:
      plugin: Name of the plugin under test.
      ext_deps: List of Maven coordinates for external test dependencies.
      ext_repo: Name of the external repository generated by rules_jvm_external.
        Defaults to `<plugin>_plugin_deps`.
      name: Name of the java_library rule. Defaults to
        `<plugin>__plugin_test_deps`, which is the name expected by Eclipse
        classpath generation.
      tags: Optional list of tags for the helper target. If `plugin` is set, it
        is added automatically if not already present.
    """
    if not plugin:
        fail("gerrit_plugin_ext_test_deps: `plugin` must be set")

    if name == None:
        name = _plugin_test_deps_name(plugin)

    if ext_repo == None:
        ext_repo = plugin + "_plugin_deps"

    if tags == None:
        tags = []

    if plugin not in tags:
        tags = tags + [plugin]

    java_library(
        name = name,
        testonly = True,
        visibility = ["//visibility:public"],
        exports = _artifacts(ext_deps, ext_repo),
        tags = tags,
    )

def gerrit_plugin_tests(
        name = None,
        srcs = [],
        deps = [],
        plugin = "",
        ext_deps = [],
        ext_deps_label = None,
        ext_repo = None,
        tags = None,
        **kwargs):
    """Runs junit tests for a Gerrit plugin.

    Args:
      name: Name of the junit test target. Defaults to `<plugin>_tests`.
      srcs: List of Java source files for the plugin tests.
      deps: List of additional Bazel dependencies for the test target.
      plugin: Name of the plugin under test. Only required if `ext_deps`,
        `ext_deps_label`, or automatic plugin target wiring is used. Only one
        of `ext_deps` or `ext_deps_label` is allowed.
      ext_deps: List of Maven coordinates for external test dependencies.
        When set, dependencies are added directly to the test target. Use
        `gerrit_plugin_ext_test_deps()` to create the optional Eclipse
        classpath helper target.
      ext_deps_label: Optional label of a java_library that exports external
        test dependencies, for example a target created by
        `gerrit_plugin_ext_test_deps()`. Only either `ext_deps` or
        `ext_deps_label` is allowed.
      ext_repo: Name of the external repository generated by rules_jvm_external.
        Defaults to `<plugin>_plugin_deps`.
      tags: Optional list of tags for the test target. If `plugin` is set, it
        is added automatically if not already present.
      **kwargs: Additional arguments passed to the underlying `junit_tests` rule.
    """

    if "exports" in kwargs:
        fail("gerrit_plugin_tests: `exports` is no longer supported; use `deps`, `ext_deps`, or `ext_deps_label`")

    if ext_deps and ext_deps_label:
        fail("Only one of `ext_deps` or `ext_deps_label` may be provided.")

    if plugin:
        if name == None:
            name = plugin + "_tests"
        if ext_repo == None:
            ext_repo = plugin + "_plugin_deps"
    elif name == None:
        fail("gerrit_plugin_tests: `name` must be set when `plugin` is empty")
    elif ext_deps or ext_deps_label:
        fail("gerrit_plugin_tests: `plugin` must be set when test dependencies are provided")

    if tags == None:
        tags = []

    if plugin and plugin not in tags:
        tags = tags + [plugin]

    if plugin:
        deps = [":%s__plugin" % plugin] + deps

    if ext_deps:
        deps = deps + _artifacts(ext_deps, ext_repo)
    if ext_deps_label:
        deps = deps + [ext_deps_label]

    junit_tests(
        name = name,
        srcs = srcs,
        deps = deps + gerrit_api() + gerrit_acceptance_framework(),
        tags = tags,
        **kwargs
    )

def gerrit_plugin_test_util(
        name,
        srcs = [],
        deps = [],
        plugin = None,
        ext_deps = [],
        ext_deps_label = None,
        ext_repo = None,
        **kwargs):
    """Creates a test utility library for a Gerrit plugin.

     This is intended for code that is only used by tests and should not be
     included in the plugin JAR.

    Args:
      name: The name of the test utility library.
      deps: List of additional dependencies for the test utility library.
      srcs: List of Java source files for the test utility library.
      plugin: Name of the plugin under test. When set, the
        `:<plugin>__plugin` target is prepended to `deps` automatically
        (test utilities typically need the plugin's own classes on the
        compile classpath). Also used to derive `ext_repo` when `ext_deps`
        is set. Optional.
      ext_deps: List of Maven coordinates for external dependencies. When
        non-empty, the coordinates are resolved against `ext_repo` (or
        `<plugin>_plugin_deps` if `ext_repo` is not given) and appended to
        `deps`. Either `plugin` or `ext_repo` must be set when `ext_deps`
        is provided. Only either `ext_deps` or `ext_deps_label` is allowed.
      ext_deps_label: Optional label of a java_library that exports external
        dependencies, for example a target created by
        `gerrit_plugin_ext_test_deps()`. Only either `ext_deps` or
        `ext_deps_label` is allowed.
      ext_repo: Name of the external repository generated by rules_jvm_external.
        Defaults to `<plugin>_plugin_deps` when `plugin` is set.
      **kwargs: Additional arguments passed to the underlying `java_library` rule.
    """

    if ext_deps and ext_deps_label:
        fail("Only one of `ext_deps` or `ext_deps_label` may be provided.")

    if plugin:
        deps = [":%s__plugin" % plugin] + deps

    if ext_deps:
        if ext_repo == None:
            if plugin == None:
                fail("gerrit_plugin_test_util: `plugin` or `ext_repo` must be set when `ext_deps` is provided")
            ext_repo = plugin + "_plugin_deps"
        deps = deps + _artifacts(ext_deps, ext_repo)
    elif ext_deps_label:
        deps = deps + [ext_deps_label]

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
        overlap_against = None,
        target = None):
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
      target: Optional Bazel label of the runtime-classpath-providing target
              to inspect. Defaults to `:{plugin}__plugin` (the library created
              by `gerrit_plugin()`). Pass an explicit label when the runtime
              jars are carried by something other than a `gerrit_plugin()`
              target — e.g. a standalone `java_library` consumed by a sibling
              `java_binary`.

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
    plugin_target = target if target else ":%s__plugin" % plugin

    if not allowlist:
        allowlist = ":%s_third_party_runtime_jars.allowlist.txt" % plugin

    allowlist_test = plugin + "_dependency_allowlist_test"
    allowlist_manifest = allowlist_test + "_manifest"
    package_name = native.package_name()
    if package_name:
        allowlist_hint = "//%s:%s" % (package_name, allowlist_manifest)
    else:
        allowlist_hint = ":%s" % allowlist_manifest

    runtime_jars_allowlist_test(
        name = allowlist_test,
        target = plugin_target,
        allowlist = allowlist,
        hint = allowlist_hint,
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
