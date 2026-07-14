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
load("//tools:flavour.bzl", "flavour_only", "flavoured_jar")
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

    When flavour == "ee11" the jakarta.servlet plugin API is selected instead of
    the default javax.servlet one. In-tree (Gerrit is the main module) the
    flavour-aware `//plugins:plugin-lib-neverlink` already flips to jakarta under
    `--@com_googlesource_gerrit_bazlets//flags:flavour=ee11`, so no per-flavour
    label is needed there. Standalone
    builds resolve the suffixed `..._gerrit_plugin_api_ee11` artifact, which the
    plugin's own module must declare in its `external_plugin_deps` maven.install.
    """
    if not native.module_name():
        # Gerrit and/or plugin does not use bazel modules yet; use Gerrit API from
        # maven repository as defined in gerrit_api.bzl
        # TODO(thomas): Remove after migration to Bazel modules is complete
        return PLUGIN_DEPS_NEVERLINK
    elif native.module_name() == "gerrit":
        # In-tree build, i.e. Gerrit is the main module; use Gerrit API from Gerrit
        # source tree. This target is flavour-aware via select() on //tools:ee11;
        # the ee11 jar is produced by the gerrit_plugin(flavour = "ee11") target,
        # which self-transitions the flavour (no command-line flag needed).
        return ["//plugins:plugin-lib-neverlink"]
    else:
        # Standalone build; use Gerrit API from maven repository as defined in
        # plugin's module.
        api = "com_google_gerrit_gerrit_plugin_api"
        if flavour == "ee11":
            api = "com_google_gerrit_gerrit_plugin_api_ee11"
        java_library(
            name = name + "-gerrit-api-neverlink",
            neverlink = 1,
            visibility = ["//visibility:public"],
            exports = ["@external_plugin_deps//:" + api],
        )
        return [":" + name + "-gerrit-api-neverlink"]

def gerrit_api(flavour = None):
    """Return the correct Gerrit API dependency for the current build mode.

    Args:
      flavour: Optional servlet flavour. When `"ee11"`, standalone builds
        resolve the suffixed `..._gerrit_plugin_api_ee11` artifact, which the
        plugin's own module must declare in its `external_plugin_deps`
        maven.install (mirroring `gerrit_api_neverlink`). In-tree the
        unsuffixed target is flavour-aware via select() on the active
        configuration and needs no per-flavour label.
    """
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
        api = "com_google_gerrit_gerrit_plugin_api"
        if flavour == "ee11":
            api = "com_google_gerrit_gerrit_plugin_api_ee11"
        return ["@external_plugin_deps//:" + api]

def gerrit_acceptance_framework(flavour = None):
    """
    Return the correct Gerrit Acceptance Framework dependency for the current
    build mode.

    Args:
      flavour: Optional servlet flavour. When `"ee11"`, standalone builds
        resolve the suffixed `..._gerrit_acceptance_framework_ee11` artifact,
        which the plugin's own module must declare in its
        `external_plugin_deps` maven.install. In-tree the acceptance library
        is flavour-aware via the active configuration.
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
        framework = "com_google_gerrit_gerrit_acceptance_framework"
        if flavour == "ee11":
            framework = "com_google_gerrit_gerrit_acceptance_framework_ee11"
        return ["@external_plugin_deps//:" + framework]

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
        canonical = "javax",
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
      flavour: Servlet flavour marker stamped into the plugin manifest as
        `Gerrit-Flavour`, which Gerrit's plugin loader checks to reject a flavour
        mismatch at load time. One of:
          `None`  default: no marker (an unmarked plugin is treated as ee8, for
                  backward compatibility with the existing plugin base).
          `"ee8"`  javax.servlet; emits `Gerrit-Flavour: ee8` and guards the
                   target to the ee8 configuration. Declare it on the
                   default target when adding an ee11 twin, so the ee11
                   wildcard pass skips the javax side (and its dependency
                   tests, via incompatibility propagation) instead of
                   failing -- both wildcard passes stay green at every
                   migration stage.
          `"ee11"` jakarta.servlet; rewrites the sources javax->jakarta via the
                   shared `to_jakarta` transform, emits `Gerrit-Flavour: ee11`,
                   and selects the jakarta Gerrit plugin API. Build with a
                   distinct `name` (e.g. `<plugin>-ee11`) and `dir_name`.
          `"any"`  audited servlet-neutral; emits `Gerrit-Flavour: any` so the
                   plugin loads under either flavour. No transform, no guard.
        An unflavoured (flavour = None) target is left unchanged. See
        `tools/servlet_transform.bzl`.
      canonical: Which servlet namespace the plugin sources are written in.
        `"javax"` (default): sources are javax.servlet; `flavour = "ee11"`
        generates the jakarta twin via the `to_jakarta` transform.
        `"jakarta"`: sources are jakarta.servlet (the JGit-style reversed
        bridge); `flavour = "ee8"` generates the javax twin via `to_javax`
        and is guarded to the ee8 configuration, while `flavour = "ee11"`
        compiles the canonical sources directly (still self-transitioning,
        since the jakarta plugin API only resolves under flavour=ee11).
        Jakarta-canonical plugins must declare `flavour` explicitly as
        `"ee8"` or `"ee11"`: an unmarked jar is treated as ee8 by the
        loader, which would be wrong for a jakarta jar.
      flavour_src_prefix: Path prefix stripped from each source when building the
        flavour srcjar. Defaults to `"src/main/java/"` (the standard plugin layout).
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

    if flavour not in (None, "ee8", "ee11", "any"):
        fail("gerrit_plugin: `flavour` must be one of None, \"ee8\", \"ee11\", \"any\"")

    if canonical not in ("javax", "jakarta"):
        fail("gerrit_plugin: `canonical` must be \"javax\" or \"jakarta\"")

    if canonical == "jakarta" and flavour not in ("ee8", "ee11"):
        fail("gerrit_plugin: jakarta-canonical plugins must declare " +
             "flavour = \"ee8\" or \"ee11\"")

    if ext_repo == None:
        ext_repo = name + "_plugin_deps"

    deps = deps + _artifacts(ext_deps, ext_repo)

    # Stamp the servlet flavour into the manifest as `Gerrit-Flavour`, which
    # Gerrit's plugin loader (GerritServerFlavour) checks to reject a flavour
    # mismatch at load time. The non-canonical flavour is generated by the
    # shared servlet transform: javax-canonical plugins rewrite to_jakarta for
    # ee11, jakarta-canonical plugins rewrite to_javax for ee8. The canonical
    # side uses its sources unchanged and only adds the marker. An unmarked
    # (flavour = None) plugin is treated as ee8 by the loader.
    transform_direction = None
    if canonical == "javax" and flavour == "ee11":
        transform_direction = "to_jakarta"
    elif canonical == "jakarta" and flavour == "ee8":
        transform_direction = "to_javax"

    if transform_direction:
        srcjar = name + "__" + flavour + "_srcjar"
        transform_srcjar(
            name = srcjar,
            direction = transform_direction,
            sources = srcs,
            src_prefix = flavour_src_prefix,
        )
        srcs = [":" + srcjar]

    if flavour == "ee11":
        manifest_entries = manifest_entries + ["Gerrit-Flavour: ee11"]
    elif flavour in ("ee8", "any"):
        manifest_entries = manifest_entries + ["Gerrit-Flavour: " + flavour]

    # The ee11 intermediates compile jakarta sources, which only resolve under
    # the flavour=ee11 configuration. Guard them so default wildcard builds
    # skip them; the public flavoured_jar wrapper transitions the flavour and
    # builds them in the jakarta configuration.
    flavour_compatible = []
    if flavour == "ee11":
        flavour_compatible = flavour_only("ee11")
    elif flavour == "ee8":
        # An explicitly ee8-flavoured plugin target compiles against the
        # plugin API the active configuration resolves; under flavour=ee11
        # that would be jakarta. Guard it to the ee8 configuration,
        # mirroring the ee11 guard above: the ee11 wildcard pass then
        # *skips* the javax side -- and, via incompatibility propagation,
        # its deploy jar and dependency tests -- instead of failing to
        # compile javax sources against the jakarta API. This holds for
        # both canonical directions (the generated javax twin of a
        # jakarta-canonical plugin, and the javax default of a plugin that
        # has grown an ee11 twin), keeping BOTH wildcard passes green at
        # every migration stage:
        #   bazel test plugins/<plugin>/...
        #   bazel test --//flags:flavour=ee11 plugins/<plugin>/...
        flavour_compatible = flavour_only("ee8")

    java_library(
        name = name + "__plugin",
        srcs = srcs,
        resources = resources,
        deps = deps + gerrit_api_neverlink(name, flavour),
        runtime_deps = runtime_deps,
        target_compatible_with = flavour_compatible,
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

    # For the EE11 flavour the public target is a flavoured_jar wrapper that
    # builds the (transform-fed) jar under a flavour=ee11 transition, so the
    # plugin self-selects the jakarta config. The genrule that assembles the jar
    # therefore gets an internal name and the wrapper takes the public one.
    final_target = name + target_suffix
    jar_target = final_target + "__flavour_jar" if flavour == "ee11" else final_target

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

    if flavour == "ee11":
        flavoured_jar(
            name = final_target,
            actual = ":" + jar_target,
            flavour = flavour,
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
        flavour = None,
        canonical = "javax",
        flavour_src_prefix = "src/test/java/",
        **kwargs):
    """Runs junit tests for a Gerrit plugin.

    Args:
      name: Name of the junit test target. Defaults to `<plugin>_tests`.
      srcs: List of Java source files for the plugin tests.
      deps: List of additional Bazel dependencies for the test target.
      plugin: Name of the plugin under test. Only required if `ext_deps`,
        `ext_deps_label`, or automatic plugin target wiring is used. Only one
        of `ext_deps` or `ext_deps_label` is allowed. For a flavoured test
        twin, pass the flavoured plugin target's name (e.g.
        `"my-plugin-ee11"`): the plugin library dep, the default `name`, and
        the default `ext_repo` all derive from it.
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
      flavour: Servlet flavour the tests execute in, mirroring the
        `gerrit_plugin` attribute. A flavoured plugin jar without a flavoured
        test execution is only half migrated: the artifact would be audited
        but never run. One of:
          `None`  default: the tests run in the default configuration,
                  unguarded (the pre-flavour behaviour).
          `"ee8"` javax.servlet tests, guarded to the ee8 configuration.
                  With `canonical = "jakarta"` the test sources are generated
                  via the `to_javax` transform.
          `"ee11"` jakarta.servlet tests, guarded to the ee11 configuration
                  and compiled against the jakarta plugin API and acceptance
                  framework. With the default `canonical = "javax"` the test
                  sources are generated via the `to_jakarta` transform.
        A test target cannot self-transition the flavour the way the `-ee11`
        jar targets do, so a flavoured test carries a
        `target_compatible_with` guard instead: `bazel test //...` runs the
        ee8 side and skips the ee11 twin, and the same wildcard under
        `--@com_googlesource_gerrit_bazlets//flags:flavour=ee11` runs the
        ee11 twin and skips the ee8 side — one test invocation per flavour,
        no target enumeration.
      canonical: Which servlet namespace the plugin's test sources are written
        in; same contract as `gerrit_plugin`. Jakarta-canonical tests must
        declare `flavour` explicitly as `"ee8"` or `"ee11"`.
      flavour_src_prefix: Path prefix stripped from each test source when
        building the flavour srcjar. Defaults to `"src/test/java/"` (the
        standard plugin layout).
      **kwargs: Additional arguments passed to the underlying `junit_tests` rule.
    """

    if "exports" in kwargs:
        fail("gerrit_plugin_tests: `exports` is no longer supported; use `deps`, `ext_deps`, or `ext_deps_label`")

    if ext_deps and ext_deps_label:
        fail("Only one of `ext_deps` or `ext_deps_label` may be provided.")

    if flavour not in (None, "ee8", "ee11"):
        fail("gerrit_plugin_tests: `flavour` must be one of None, \"ee8\", \"ee11\"")

    if canonical not in ("javax", "jakarta"):
        fail("gerrit_plugin_tests: `canonical` must be \"javax\" or \"jakarta\"")

    if canonical == "jakarta" and flavour == None:
        fail("gerrit_plugin_tests: jakarta-canonical tests must declare " +
             "flavour = \"ee8\" or \"ee11\"")

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

    # The non-canonical flavour's tests are generated by the shared servlet
    # transform, exactly like the plugin jar they exercise. The transform
    # preserves package and class names, so the canonical files still yield
    # the suite class list (see `suite_srcs` in junit_tests).
    transform_direction = None
    if canonical == "javax" and flavour == "ee11":
        transform_direction = "to_jakarta"
    elif canonical == "jakarta" and flavour == "ee8":
        transform_direction = "to_javax"

    suite_srcs = None
    if transform_direction:
        srcjar = name + "__" + flavour + "_srcjar"
        transform_srcjar(
            name = srcjar,
            direction = transform_direction,
            sources = srcs,
            src_prefix = flavour_src_prefix,
            testonly = True,
        )
        suite_srcs = srcs
        srcs = [":" + srcjar]

    # A test target cannot self-transition the flavour, so an explicitly
    # flavoured test carries a guard instead: it is skipped (not failed)
    # unless its flavour's configuration is active.
    if flavour:
        if "target_compatible_with" in kwargs:
            fail("gerrit_plugin_tests: `target_compatible_with` cannot be " +
                 "combined with `flavour`; the flavour guard sets it")
        kwargs = dict(kwargs, target_compatible_with = flavour_only(flavour))

    junit_tests(
        name = name,
        srcs = srcs,
        suite_srcs = suite_srcs,
        deps = deps + gerrit_api(flavour) + gerrit_acceptance_framework(flavour),
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
