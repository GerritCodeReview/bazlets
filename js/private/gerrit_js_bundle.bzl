load("@aspect_rules_rollup//rollup:defs.bzl", "rollup")
load("@com_googlesource_gerrit_bazlets//tools:genrule2.bzl", "genrule2")

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
            node_modules + "/@rollup/plugin-terser",
        ],
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
