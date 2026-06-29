"""EE10 (jakarta.servlet) flavour transition + plugin-jar wrapper.

The servlet flavour is the `//flags:flavour` string build setting (ee8 default,
ee10 opt-in; see flags/BUILD.bazel). This file provides:

  * ee10_transition  -- a configuration transition that forces flavour=ee10 for
    a target's whole subgraph, independent of the command-line flag.
  * ee10_flavour_jar -- a thin rule that builds its `actual` dep under that
    transition and republishes its jar. gerrit_plugin(flavour = "ee10") wraps
    its output in this rule so an EE10 plugin self-selects the jakarta config:
    `bazelisk build //plugins/foo:foo-ee10` works with no flag, and builds
    cleanly alongside the EE8 `//plugins/foo:foo` in a single invocation.
  * ee10_war -- the same wrapper for a pkg_war target, so Gerrit's
    release-ee10.war / headless-ee10.war build under the transition alongside the
    default EE8 WARs in one invocation.

Keeping this in bazlets (rather than Gerrit) is what lets the shared
gerrit_plugin macro reference the transition -- a macro in bazlets cannot name a
Gerrit `//tools:...` label.
"""

def _ee10_transition_impl(_settings, _attr):
    return {"//flags:flavour": "ee10"}

ee10_transition = transition(
    implementation = _ee10_transition_impl,
    inputs = [],
    outputs = ["//flags:flavour"],
)

def _ee10_flavour_jar_impl(ctx):
    jars = [f for f in ctx.files.actual if f.extension == "jar"]
    if len(jars) != 1:
        fail("ee10_flavour_jar: expected exactly one .jar from %s, got %s" %
             (ctx.attr.actual.label, jars))
    out = ctx.actions.declare_file(ctx.label.name + ".jar")
    ctx.actions.symlink(output = out, target_file = jars[0])
    return [DefaultInfo(files = depset([out]))]

ee10_flavour_jar = rule(
    implementation = _ee10_flavour_jar_impl,
    cfg = ee10_transition,
    doc = "Builds `actual` with flavour=ee10 forced; republishes its jar as <name>.jar.",
    attrs = {
        "actual": attr.label(
            allow_files = [".jar"],
            mandatory = True,
            doc = "The plugin jar target to build in the EE10 flavour.",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _ee10_war_impl(ctx):
    wars = [f for f in ctx.files.war if f.extension == "war"]
    if len(wars) != 1:
        fail("ee10_war: expected exactly one .war from %s, got %s" % (ctx.attr.war.label, wars))
    out = ctx.actions.declare_file(ctx.label.name + ".war")
    ctx.actions.symlink(output = out, target_file = wars[0])
    return [DefaultInfo(files = depset([out]))]

ee10_war = rule(
    implementation = _ee10_war_impl,
    cfg = ee10_transition,
    doc = "Builds the wrapped pkg_war with flavour=ee10 forced; output named <name>.war.",
    attrs = {
        "war": attr.label(
            allow_files = [".war"],
            mandatory = True,
            doc = "The WAR target to build in the EE10 flavour (its .war output is used).",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
