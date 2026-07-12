"""Servlet-flavour build machinery: transition, output wrappers, BUILD helpers.

# What a "flavour" is

Gerrit -- and the JGit / Gitiles / plugin artifacts it builds on -- can be built
against more than one Servlet API namespace *and version*. A *flavour* is the
whole coordinated bundle that must move together; you cannot mix pieces from two
rows on one classpath:

    flavour   Servlet API             Jetty environment     Guice
    -------   ---------------------   -------------------   -----
    ee11      jakarta.servlet 6.1     Jetty EE11            7
    ee12      jakarta.servlet 7.0     Jetty EE12 (Jetty 13) ...
    (retired: ee8 -- javax.servlet 4.0, Jetty EE8, Guice 6)

The active flavour is chosen by the `//flags:flavour` string build setting (see
flags/BUILD.bazel): `ee11` is the default and, since the EE8 retirement, the
only value. `//flags:ee11` is the config_setting that matches when the flag
equals `ee11`, and every flavour-bearing `select()` / guard keys off such
per-flavour settings.

`flavour` is a *string*, not a boolean, precisely because this is an open set:
new jakarta flavours are added over time as Jakarta EE / Jetty advance, and more
than one jakarta flavour can be supported at once.

# What this file provides

Configuration transition + output wrappers -- build multiple flavours in one
invocation with no command-line flag (the `-<flavour>` targets self-transition
via the `flavour` attribute):

  * flavour_transition -- forces `//flags:flavour` to a target's `flavour`
    attribute for its whole subgraph, independent of the command-line flag.
  * flavoured_jar      -- builds `actual` under that transition and republishes
    its jar. gerrit_plugin(flavour = "ee11") wraps its output in this, so
    `bazelisk build //plugins/foo:foo-ee11` self-selects the jakarta config and
    builds alongside the EE8 `//plugins/foo:foo` in one invocation.
  * flavoured_file     -- same, for a single output file of any type (a deploy
    jar, a -sources.jar, a javadoc .zip); used to publish the
    gerrit-plugin-api-<flavour> jar/sources/javadoc artifacts.
  * flavoured_war      -- same wrapper for a pkg_war, so release-ee11.war /
    headless-ee11.war build under the transition next to the EE8 WARs.

BUILD-file helpers -- collapse the per-target `select()` / guard boilerplate so
the `//flags:*` seam is written once, not at every boundary target, and so adding
a flavour is a new map entry rather than an edit at every call site. The flavour
is a *parameter*, never baked into the helper name:

  * flavour_only          -- a `target_compatible_with` value marking a target
    buildable ONLY in the given jakarta flavour(s); the default `//...` wildcard
    skips it (instead of failing to compile jakarta sources against javax).
  * flavoured_alias       -- an `alias` resolving to a `default` (EE8) target or
    a per-flavour jakarta target ({flavour: target}); consumers depend on the
    flavour-neutral name.
  * flavoured_twin_alias  -- a `flavoured_alias` for same-package "twin" targets
    named `:<name>-<flavour>`; list only the jakarta flavours and the twin
    labels are derived.
  * flavoured_java_library -- a `java_library` with the flavour_only guard
    injected for its `flavour`.
  * flavoured_library     -- the whole mechanical twin family from one call: the
    default leaf, the javax->jakarta source transform(s), the guarded per-flavour
    leaf/leaves, and the flavoured_twin_alias over them -- so the deps list is
    written once and the `-<flavour>` suffixes are never spelled. For libraries
    whose jakarta flavour is a pure source transform (no hand-written overlays).
  * flavoured_junit_tests  -- a `junit_tests` with the flavour_only guard
    injected for its `flavour`.

# Why this lives in bazlets

Keeping it here (rather than in Gerrit) is what lets the shared gerrit_plugin
macro reference the transition -- a macro defined in bazlets cannot name a Gerrit
`//tools:...` label. For the same reason the BUILD-file helpers live here too, so
Gerrit, Gitiles, and standalone plugins share ONE flavour vocabulary, all keyed
on the bazlets `//flags:ee11` config_setting. (Gerrit's `//tools:ee11` is an
equivalent local mirror of the same flag/value, kept for its remaining in-tree
selects.)
"""

load("@rules_java//java:defs.bzl", "java_library")
load("//tools:flavour_constants.bzl", "KNOWN_FLAVOURS")
load("//tools:junit.bzl", "junit_tests")
load("//tools:servlet_transform.bzl", "transform_srcjar")

def _check_known_flavour(caller, flavour):
    if type(flavour) != "string":
        fail("%s: flavour must be a string, got %s" % (caller, type(flavour)))
    if flavour not in KNOWN_FLAVOURS:
        fail("%s: unsupported flavour %s; known flavours are %s" %
             (caller, flavour, KNOWN_FLAVOURS))

def _check_non_default_flavour(caller, flavour, default_flavour = "ee11"):
    _check_known_flavour(caller, flavour)
    if flavour == default_flavour:
        fail("%s: `flavours` lists non-default flavours; got default flavour %s" %
             (caller, flavour))

def flavour_only(*flavours):
    """`target_compatible_with` value: buildable ONLY when a listed flavour is active.

    In any other flavour's config the target is marked incompatible, so
    `bazel build //...` / `bazel test //...` skip it instead of failing to
    compile its jakarta sources against the javax tier. Build/run it under
    `--//flags:flavour=<flavour>` or via a self-transitioning `-<flavour>` target.

    Args:
      *flavours: one or more flavour names (e.g. "ee11"), each mapped to its
        `//flags:<flavour>` config_setting.
    """
    conditions = {"//conditions:default": ["@platforms//:incompatible"]}
    for flavour in flavours:
        _check_known_flavour("flavour_only", flavour)

        # Label() anchors the config_setting to THIS (bazlets) repo; a bare
        # string would resolve in the calling BUILD's repo (e.g. Gerrit), which
        # has no //flags package.
        conditions[Label("//flags:" + flavour)] = []
    return select(conditions)

def flavoured_alias(name, default, flavours, default_flavour = "ee11", visibility = None):
    """`alias` resolving to `default` by default, or a per-flavour target under the flag.

    Collapses the repeated boundary pattern `alias(actual = select({...}))`:
    consumers depend on the flavour-neutral `name` and transparently get the
    `default` flavour's target, or the matching per-flavour target when that
    flavour's flag is active. The impls share FQDNs, so only one is ever on a
    classpath. Keeping the `select()` inside this macro means the `//flags:*`
    seam is written once, not per boundary target, and adding a flavour is a new
    map entry rather than an edit at every call site.

    Args:
      name: the flavour-neutral alias label consumers depend on.
      default: target for the default (no-flag) flavour.
      flavours: {flavour: target} for each non-default flavour, e.g.
        {"ee11": ":httpd-ee11"}.
      default_flavour: the default (no-flag) flavour that `default` serves,
        used to validate that `flavours` lists only non-default flavours
        (default "ee11").
      visibility: alias visibility.
    """
    conditions = {"//conditions:default": default}
    for flavour, target in flavours.items():
        _check_non_default_flavour("flavoured_alias", flavour, default_flavour)

        # Label() anchors the config_setting to THIS (bazlets) repo; a bare
        # string would resolve in the calling BUILD's repo (e.g. Gerrit).
        conditions[Label("//flags:" + flavour)] = target
    native.alias(name = name, actual = select(conditions), visibility = visibility)

def flavoured_twin_alias(name, flavours, default_flavour = "ee11", **kwargs):
    """`flavoured_alias` for same-package "twin" targets named `:<name>-<flavour>`.

    Convention over configuration for source-divergent library twins (e.g.
    `httpd` -> `:httpd-ee8` / `:httpd-ee11`): list only the jakarta `flavours`
    and the `:<name>-<flavour>` twin labels are derived. Use the generic
    `flavoured_alias` when the targets do not follow this naming (e.g. cross-repo
    or maven-jar routes such as gitiles-servlet-jar). Keeping `flavours` explicit
    (not auto-discovered) makes a missing `:<name>-ee11` twin a visible edit when
    a new flavour is added.

    Args:
      name: the flavour-neutral alias, and the `<name>-<flavour>` twin prefix.
      flavours: non-default flavour names that have a `:<name>-<flavour>` twin,
        e.g. `["ee11"]`.
      default_flavour: the default (no-flag) flavour, whose twin is
        `:<name>-<default_flavour>` (default "ee11").
      **kwargs: forwarded to `flavoured_alias` (e.g. `visibility`).
    """
    _check_known_flavour("flavoured_twin_alias", default_flavour)
    if type(flavours) != "list":
        fail("flavoured_twin_alias: `flavours` must be a list of strings, " +
             "got %s" % type(flavours))
    for flavour in flavours:
        _check_non_default_flavour("flavoured_twin_alias", flavour, default_flavour)

    flavoured_alias(
        name = name,
        default = ":%s-%s" % (name, default_flavour),
        flavours = {flavour: ":%s-%s" % (name, flavour) for flavour in flavours},
        default_flavour = default_flavour,
        **kwargs
    )

def flavoured_java_library(name, flavour, target_compatible_with = [], **kwargs):
    """`java_library` buildable ONLY in `flavour`; the flavour guard is injected.

    Injects `flavour_only(flavour)` so the default `//...` wildcard skips the
    target instead of failing to compile its jakarta sources against the javax
    tier. Any caller-supplied `target_compatible_with` is merged, not overwritten.
    """
    java_library(
        name = name,
        target_compatible_with = flavour_only(flavour) + target_compatible_with,
        **kwargs
    )

def flavoured_library(
        name,
        srcs,
        flavours = None,
        default_flavour = "ee11",
        canonical = None,
        src_prefix = "java/",
        direction = "to_jakarta",
        visibility = ["//visibility:public"],
        **kwargs):
    """The whole servlet-flavour twin family for a *mechanical* library, in one call.

    A library is *mechanical* when each non-default flavour is a straight
    javax->jakarta source transform of the same `srcs` -- no hand-written
    overlays and no excluded files. For those, this collapses the four
    hand-written targets (alias + default leaf + transform + flavour leaf) into a
    single call that never spells the `-<flavour>` suffixes and takes the `deps`
    (and any other library kwargs) once. It emits:

      `<name>-<default_flavour>`  java_library compiled from `srcs`
      `<name>-<flavour>-srcs`     transform_srcjar of `srcs`   (one per flavour)
      `<name>-<flavour>`          flavoured_java_library from the transformed srcs
      `<name>`                    flavoured_twin_alias routing by active flavour

    The `deps` no longer need extracting into a shared constant to keep the twins
    in sync: there is a single call site, so `deps = [...]` inline is DRY.

    Use the explicit `flavoured_java_library` + `flavoured_twin_alias` form when a
    flavour is NOT a pure transform -- e.g. `pgm/http/jetty`, whose ee11 twin
    excludes two files and adds hand-written Jetty-12 overlays.

    Args:
      name: flavour-neutral label consumers depend on; also the twin prefix.
      srcs: sources for the default leaf and the transform input (e.g. a `:srcs`
        filegroup).
      flavours: non-default flavour names to generate twins for. Defaults to
        every non-default flavour in KNOWN_FLAVOURS, so a mechanical library
        gains a new flavour's twin when it is added to KNOWN_FLAVOURS -- no
        call-site edit -- PROVIDED the transform already produces that flavour's
        sources. (Today `to_jakarta` maps javax->jakarta and Jetty ee8->ee11;
        jakarta.servlet is version-stable so this serves ee11/ee11/ee12, but a
        flavour needing a different source mapping must extend the transform
        first.) Because the twins are generated (not hand-written), there is no
        missing-twin risk to justify spelling this per
        call, unlike flavoured_twin_alias.
      default_flavour: the default (no-flag) flavour (default "ee11").
      canonical: which flavour the `srcs` are written in. Defaults to
        `default_flavour`: the default leaf compiles `srcs`, every other
        flavour is transform-generated.
      src_prefix: `transform_srcjar` src_prefix (default "java/").
      direction: `transform_srcjar` direction for generated twins
        (default "to_jakarta").
      visibility: applied to the alias, every twin, and the generated transforms
        (default public).
      **kwargs: forwarded to EVERY generated library twin (deps, resources,
        resource_strip_prefix, ...).
    """
    if flavours == None:
        flavours = [f for f in KNOWN_FLAVOURS if f != default_flavour]
    if type(flavours) != "list":
        fail("flavoured_library: `flavours` must be a list, got %s" % type(flavours))
    for flavour in flavours:
        _check_non_default_flavour("flavoured_library", flavour, default_flavour)
    if canonical == None:
        canonical = default_flavour
    if canonical not in [default_flavour] + flavours:
        fail("flavoured_library: `canonical` must be the default flavour or " +
             "one of `flavours`, got %s" % canonical)
    flavoured_java_library(
        name = "%s-%s" % (name, canonical),
        srcs = srcs,
        flavour = canonical,
        visibility = visibility,
        **kwargs
    )
    for flavour in [default_flavour] + flavours:
        if flavour == canonical:
            continue
        transform_srcjar(
            name = "%s-%s-srcs" % (name, flavour),
            direction = direction,
            sources = srcs,
            src_prefix = src_prefix,
            visibility = visibility,
        )
        flavoured_java_library(
            name = "%s-%s" % (name, flavour),
            srcs = [":%s-%s-srcs" % (name, flavour)],
            flavour = flavour,
            visibility = visibility,
            **kwargs
        )
    flavoured_twin_alias(
        name = name,
        flavours = flavours,
        default_flavour = default_flavour,
        visibility = visibility,
    )

def flavoured_junit_tests(name, flavour, target_compatible_with = [], **kwargs):
    """`junit_tests` buildable ONLY in `flavour`, for forward-generated flavour tests."""
    junit_tests(
        name = name,
        target_compatible_with = flavour_only(flavour) + target_compatible_with,
        **kwargs
    )

def flavoured_tests(
        name,
        srcs,
        flavours = None,
        default_flavour = "ee11",
        canonical = None,
        src_prefix = "javatests/",
        direction = "to_jakarta",
        **kwargs):
    """The mechanical servlet-flavour test twins in one call -- flavoured_library for tests.

    Test analogue of flavoured_library. Emits the default-flavour suite as
    `<name>` (compiled from `srcs`) and, for each non-default flavour, the
    javax->jakarta transform `<name>-<flavour>-srcs` plus a guarded suite
    `<name>-<flavour>` compiled from it. The transformed suite gets
    `suite_srcs = srcs` so its @RunWith(Suite) class list is derived from the
    original .java files rather than the generated .srcjar. No alias is emitted
    (nothing depends on a test target) and the default suite keeps the plain
    `<name>` so it stays the runnable target. `**kwargs` (deps, ...) apply to
    every suite, so the deps are written once.

    For *mechanical* tests only (the jakarta sources are a pure transform).
    Hand-written test fakes that diverge -- e.g. the util/http testutil ee11
    fakes -- stay in their own targets.

    Args:
      name: the default-flavour (runnable) suite; also the twin prefix.
      canonical: which flavour the `srcs` are written in; defaults to
        `default_flavour` (the canonical suite compiles `srcs` directly;
        other flavours' suites are transform-generated).
      srcs: the test sources (e.g. `glob(["**/*.java"])`), reused for the
        default suite, the transform input, and each transformed suite's
        `suite_srcs`.
      flavours: non-default flavour names to generate suites for. Defaults to
        every non-default flavour in KNOWN_FLAVOURS (like flavoured_library), so
        a mechanical test suite gains a new flavour's twin when it is added to
        KNOWN_FLAVOURS, subject to the same transform caveat as flavoured_library.
      default_flavour: the default (no-flag) flavour (default "ee11").
      src_prefix: `transform_srcjar` src_prefix (default "javatests/").
      direction: `transform_srcjar` direction (default "to_jakarta").
      **kwargs: forwarded to every generated suite (deps, ...).
    """
    if flavours == None:
        flavours = [f for f in KNOWN_FLAVOURS if f != default_flavour]
    if type(flavours) != "list":
        fail("flavoured_tests: `flavours` must be a list, got %s" % type(flavours))
    for flavour in flavours:
        _check_non_default_flavour("flavoured_tests", flavour, default_flavour)
    if canonical == None:
        canonical = default_flavour
    if canonical not in [default_flavour] + flavours:
        fail("flavoured_tests: `canonical` must be the default flavour or " +
             "one of `flavours`, got %s" % canonical)
    canonical_target = name if canonical == default_flavour else "%s-%s" % (name, canonical)
    flavoured_junit_tests(
        name = canonical_target,
        srcs = srcs,
        flavour = canonical,
        **kwargs
    )
    for flavour in [default_flavour] + flavours:
        if flavour == canonical:
            continue
        target = name if flavour == default_flavour else "%s-%s" % (name, flavour)
        transform_srcjar(
            name = "%s-srcs" % target,
            direction = direction,
            sources = srcs,
            src_prefix = src_prefix,
        )
        flavoured_junit_tests(
            name = target,
            srcs = [":%s-srcs" % target],
            flavour = flavour,
            suite_srcs = srcs,
            **kwargs
        )

def _flavour_transition_impl(_settings, attr):
    return {"//flags:flavour": attr.flavour}

flavour_transition = transition(
    implementation = _flavour_transition_impl,
    inputs = [],
    outputs = ["//flags:flavour"],
)

def _flavoured_jar_impl(ctx):
    jars = [f for f in ctx.files.actual if f.extension == "jar"]
    if len(jars) != 1:
        fail("flavoured_jar: expected exactly one .jar from %s, got %s" %
             (ctx.attr.actual.label, jars))
    out = ctx.actions.declare_file(ctx.label.name + ".jar")
    ctx.actions.symlink(output = out, target_file = jars[0])
    return [DefaultInfo(files = depset([out]))]

flavoured_jar = rule(
    implementation = _flavoured_jar_impl,
    cfg = flavour_transition,
    doc = "Builds `actual` with the given `flavour` forced; republishes its jar as <name>.jar.",
    attrs = {
        "actual": attr.label(
            allow_files = [".jar"],
            mandatory = True,
            doc = "The plugin jar target to build in the given flavour.",
        ),
        "flavour": attr.string(
            mandatory = True,
            values = KNOWN_FLAVOURS,
            doc = "Flavour to force for `actual`, e.g. \"ee11\".",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _flavoured_file_impl(ctx):
    files = ctx.files.actual
    if len(files) != 1:
        fail("flavoured_file: expected exactly one file from %s, got %s" %
             (ctx.attr.actual.label, files))
    src = files[0]
    ext = ("." + src.extension) if src.extension else ""

    # Avoid double-suffixing when the target name already ends with the input's
    # extension (e.g. a "release-ee11.war.jars.txt" target fed a ".txt" file).
    name = ctx.label.name if (ext and ctx.label.name.endswith(ext)) else ctx.label.name + ext
    out = ctx.actions.declare_file(name)
    ctx.actions.symlink(output = out, target_file = src)
    return [DefaultInfo(files = depset([out]))]

flavoured_file = rule(
    implementation = _flavoured_file_impl,
    cfg = flavour_transition,
    doc = ("Like flavoured_jar but for a single output file of any type " +
           "(e.g. a deploy jar, a -sources.jar, or a javadoc .zip). Builds " +
           "`actual` with the given `flavour` forced and republishes its one " +
           "output, preserving the original extension. Used by the Maven " +
           "publishing of the gerrit-plugin-api-<flavour> artifacts."),
    attrs = {
        "actual": attr.label(
            allow_files = True,
            mandatory = True,
            doc = "The single-output target to build in the given flavour.",
        ),
        "flavour": attr.string(
            mandatory = True,
            values = KNOWN_FLAVOURS,
            doc = "Flavour to force for `actual`, e.g. \"ee11\".",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _flavoured_war_impl(ctx):
    wars = [f for f in ctx.files.war if f.extension == "war"]
    if len(wars) != 1:
        fail("flavoured_war: expected exactly one .war from %s, got %s" % (ctx.attr.war.label, wars))
    out = ctx.actions.declare_file(ctx.label.name + ".war")
    ctx.actions.symlink(output = out, target_file = wars[0])
    return [DefaultInfo(files = depset([out]))]

flavoured_war = rule(
    implementation = _flavoured_war_impl,
    cfg = flavour_transition,
    doc = "Builds the wrapped pkg_war with the given `flavour` forced; output named <name>.war.",
    attrs = {
        "war": attr.label(
            allow_files = [".war"],
            mandatory = True,
            doc = "The WAR target to build in the given flavour (its .war output is used).",
        ),
        "flavour": attr.string(
            mandatory = True,
            values = KNOWN_FLAVOURS,
            doc = "Flavour to force for `war`, e.g. \"ee11\".",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
