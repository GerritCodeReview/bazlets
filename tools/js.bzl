load("@npm//@bazel/rollup:index.bzl", "rollup_bundle")
load("@npm//@bazel/terser:index.bzl", "terser_minified")
load("@com_googlesource_gerrit_bazlets//tools:genrule2.bzl", "genrule2")

def gerrit_js_bundle(
        name,
        srcs,
        entry_point,
        deps = [],
        args = [],
        config_file = None,
        rollup_bin = None,
        include_node_modules = False):
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
      deps: Additional JavaScript deps required by Rollup.
      args: Extra args for Rollup.
      config_file: Optional Rollup config file.
      rollup_bin: Optional Rollup binary target.
      include_node_modules: Whether to include @npm//:node_modules in srcs.
    """

    bundle = name + "-bundle"
    minified = name + ".min"
    main = name + ".js"

    rollup_srcs = srcs
    if include_node_modules:
        rollup_srcs = rollup_srcs + ["@npm//:node_modules"]

    rollup_kwargs = dict(
        name = bundle,
        srcs = rollup_srcs,
        entry_point = entry_point,
        format = "iife",
        sourcemap = "hidden",
        deps = deps,
        args = args,
    )
    if config_file:
        rollup_kwargs["config_file"] = config_file
    if rollup_bin:
        rollup_kwargs["rollup_bin"] = rollup_bin

    rollup_bundle(**rollup_kwargs)

    terser_minified(
        name = minified,
        sourcemap = False,
        src = bundle,
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
