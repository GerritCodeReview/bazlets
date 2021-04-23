load("@npm//@bazel/rollup:index.bzl", "rollup_bundle")
load("@npm//@bazel/terser:index.bzl", "terser_minified")
load("@com_googlesource_gerrit_bazlets//tools:genrule2.bzl", "genrule2")

def gerrit_js_bundle(name, srcs, entry_point):
    """Produces a Gerrit JavaScript bundle archive.

    This rule bundles and minifies the javascript files of a frontend plugin and
    produces a file archive.
    Output of this rule is an archive with "${name}.jar" with specific layout for
    Gerrit frontend plugins. That archive should be provided to gerrit_plugin
    rule as resource_jars attribute.

    Args:
      name: Plugin name.
      srcs: Plugin sources.
      entry_point: Plugin entry_point.
    """

    bundle = name + "-bundle"
    minified = name + ".min"
    main = name + ".js"

    rollup_bundle(
        name = bundle,
        srcs = srcs,
        entry_point = entry_point,
        format = "iife",
        sourcemap = "hidden",
    )

    terser_minified(
        name = minified,
        sourcemap = False,
        src = name + "-bundle",
    )

    native.genrule(
        name = name + "_rename_js",
        srcs = [minified],
        outs = [main],
        cmd = "cp $< $@",
        output_to_bindir = True,
    )

    genrule2(
        name = name,
        srcs = [main],
        outs = [name + ".jar"],
        cmd = " && ".join([
            "mkdir $$TMP/static",
            "cp $(SRCS) $$TMP/static",
            "cd $$TMP",
            "zip -Drq $$ROOT/$@ -g .",
        ]),
    )
