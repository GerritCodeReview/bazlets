load("@aspect_rules_rollup//rollup:defs.bzl", "rollup")
load("@com_googlesource_gerrit_bazlets//tools:genrule2.bzl", "genrule2")

def _rollup_minify(
        name,
        srcs,
        entry_point,
        rollup_config,
        node_modules):
    """Run Rollup with @rollup/plugin-terser; emit the minified bundle."""
    rollup(
        name = name,
        srcs = srcs,
        entry_point = entry_point,
        args = [
            "--bundleConfigAsCjs=true",
        ],
        format = "iife",
        silent = True,
        sourcemap = "hidden",
        config_file = rollup_config,
        node_modules = node_modules,
        deps = [
            node_modules + "/@rollup/plugin-node-resolve",
            node_modules + "/@rollup/plugin-terser",
        ],
    )

def gerrit_js_bundle(
        name,
        srcs,
        entry_point,
        rollup_config = "//plugins:rollup.config",
        node_modules = "//tools/node_tools:node_modules"):
    """Produces a Gerrit JavaScript bundle archive.

    This rule bundles and minifies frontend plugin JavaScript files with Rollup.
    Output is an archive "${name}.jar" with Gerrit frontend plugin layout.
    """

    bundle = name + "-bundle"
    main = name + ".js"

    _rollup_minify(
        name = bundle,
        srcs = srcs,
        entry_point = entry_point,
        rollup_config = rollup_config,
        node_modules = node_modules,
    )

    native.genrule(
        name = name + "_rename_js",
        srcs = [bundle],
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

def polygerrit_plugin(
        name,
        app,
        plugin_name = None,
        rollup_config = "//plugins:rollup.config",
        node_modules = "//tools/node_tools:node_modules"):
    """Produces a plugin file set with minified JavaScript.

    This rule minifies a single-source frontend plugin and exposes the
    result as a filegroup containing one .js file. Unlike gerrit_js_bundle,
    no .jar archive is produced; consumers depend on the filegroup
    directly. The source may be JavaScript or TypeScript -- Rollup handles
    both via the shared rollup_config.

    Args:
      name: Rule name. The output filegroup is named "${name}".
      app: The single root source file fed into Rollup.
      plugin_name: Filename stem for the emitted .js. Defaults to ${name}.
      rollup_config: Label of the shared Rollup config file.
      node_modules: Label of the node_modules tree the plugins resolve
        against.
    """
    if not plugin_name:
        plugin_name = name

    bundle = plugin_name + "-bundle"

    _rollup_minify(
        name = bundle,
        srcs = [app],
        entry_point = app,
        rollup_config = rollup_config,
        node_modules = node_modules,
    )

    native.genrule(
        name = name + "_rename_js",
        srcs = [bundle],
        outs = [plugin_name + ".js"],
        cmd = "cp $< $@",
        output_to_bindir = True,
    )

    native.filegroup(
        name = name,
        srcs = [plugin_name + ".js"],
    )
