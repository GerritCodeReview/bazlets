load("@npm//@bazel/terser:index.bzl", "terser_minified")

def polygerrit_plugin(name, app):
    """Bundles plugin dependencies for deployment.

    This rule minifies a plugin javascript file.
    Output of this rule is minified "${name}.js" file.

    Args:
      name: String, rule name.
      app: String, the main or root source file. This must be single JavaScript file.
    """
    terser_minified(
        name = name + ".min",
        sourcemap = False,
        src = app,
    )

    native.genrule(
        name = name + "_rename_js",
        srcs = [name + ".min"],
        outs = [name + ".js"],
        cmd = "cp $< $@",
        output_to_bindir = True,
    )

    native.filegroup(
        name = name,
        srcs = [name + ".js"],
    )
