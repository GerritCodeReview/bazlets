load("@npm//@bazel/rollup:index.bzl", "rollup_bundle")
load("@npm//@bazel/terser:index.bzl", "terser_minified")
load("//tools:genrule2.bzl", "genrule2")

def polygerrit_bundle(name, srcs, entry_point):
    """Produces PolyGerrit plugin archive.

    This rule bundles and minifies a plugin assets and produces a file archive.
    Output of this rule is a archive with "${name}.jar" with specific layout for
    Gerrit frontentd plugins. That archive should be provided to gerrit_plugin
    rule as resource_jars attribute.

    Args:
      name: Rule name.
      srcs: Plugin sources.
      entry_point: Plugin entry_point.
    """
    rollup_bundle(
        name = name + "-bundle",
        srcs = srcs,
        entry_point = entry_point,
        format = "iife",
        sourcemap = "hidden",
    )

    terser_minified(
        name = name + ".min",
        sourcemap = False,
        src = name + "-bundle.js",
    )

    genrule2(
        name = name,
        srcs = [name + ".min"],
        outs = [name + ".jar"],
        cmd = " && ".join([
            "mkdir $$TMP/static",
            "cp $(SRCS) $$TMP/static",
            "cd $$TMP",
            "zip -Drq $$ROOT/$@ -g .",
        ]),
    )
