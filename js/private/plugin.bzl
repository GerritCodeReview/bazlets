load("@aspect_rules_rollup//rollup:defs.bzl", "rollup")
load("//js/private:terser.bzl", "terser")
load("@com_googlesource_gerrit_bazlets//tools:genrule2.bzl", "genrule2")

def polygerrit_plugin(name, app, plugin_name = None, node_modules = "//tools/node_tools:node_modules"):
    """Produces plugin file set with minified javascript.

    This rule minifies a plugin javascript file, potentially renames it, and produces a file set.
    Output of this rule is a FileSet with "${plugin_name}.js".

    Args:
      name: String, rule name.
      app: String, the main or root source file. This must be single JavaScript file.
      plugin_name: String, plugin name. ${name} is used if not provided.
      node_modules: Node modules target containing rollup and terser.
    """
    if not plugin_name:
        plugin_name = name

    terser(
        name = plugin_name + ".min",
        node_modules = node_modules,
        srcs = [app],
    )

    native.genrule(
        name = name + "_rename_js",
        srcs = [plugin_name + ".min"],
        outs = [plugin_name + ".js"],
        cmd = "cp $< $@",
        output_to_bindir = True,
    )

    native.filegroup(
        name = name,
        srcs = [plugin_name + ".js"],
    )

def gerrit_js_bundle(name, srcs, entry_point, rollup_config = "//plugins:rollup.config", node_modules = "//tools/node_tools:node_modules"):
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
      rollup_config: Rollup configuration file.
      node_modules: Node modules target containing rollup and terser.
    """

    bundle = name + "-bundle"
    minified = name + ".min"
    main = name + ".js"
    rollup(
        name = bundle,
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
        ],
    )

    terser(
        name = minified,
        node_modules = node_modules,
        srcs = [bundle],
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
