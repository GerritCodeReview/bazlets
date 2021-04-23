load("@npm//@bazel/terser:index.bzl", "terser_minified")

def polygerrit_plugin(name, app, srcs = [], deps = [], assets = None, plugin_name = None, **kwargs):
    """Bundles plugin dependencies for deployment.

    This rule bundles all Polymer elements and JS dependencies into .html and .js files.
    Run-time dependencies (e.g. JS libraries loaded after plugin starts) should be provided using "assets" property.
    Output of this rule is a FileSet with "${name}_fs", with deploy artifacts in "plugins/${name}/static".

    Args:
      name: String, rule name.
      app: String, the main or root source file.
      assets: Fileset, additional files to be used by plugin in runtime, exported to "plugins/${name}/static".
      plugin_name: String, plugin name. ${name} is used if not provided.
    """
    if not plugin_name:
        plugin_name = name

    srcs = srcs if app in srcs else srcs + [app]
    js_srcs = srcs

    native.filegroup(
        name = name + "-src-fg",
        srcs = js_srcs,
    )

    terser_minified(
        name = name + ".min",
        sourcemap = False,
        src = name + "-src-fg",
    )

    native.genrule(
        name = name + "_rename_js",
        srcs = [name + ".min"],
        outs = [plugin_name + ".js"],
        cmd = "cp $< $@",
        output_to_bindir = True,
    )

    static_files = [plugin_name + ".js"]

    if assets:
        nested, direct = [], []
        for x in assets:
            target = nested if "/" in x else direct
            target.append(x)

        static_files += direct

        if nested:
            native.genrule(
                name = name + "_copy_assets",
                srcs = assets,
                outs = [f.split("/")[-1] for f in nested],
                cmd = "cp $(SRCS) $(@D)",
                output_to_bindir = True,
            )
            static_files.append(":" + name + "_copy_assets")

    native.filegroup(
        name = name,
        srcs = static_files,
    )
