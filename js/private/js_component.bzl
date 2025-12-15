ComponentInfo = provider()

def _js_component(ctx):
    dir = ctx.outputs.zip.path + ".dir"
    name = ctx.outputs.zip.basename
    if name.endswith(".zip"):
        name = name[:-4]
    dest = "%s/%s" % (dir, name)
    cmd = " && ".join([
        "TZ=UTC",
        "export TZ",
        "mkdir -p %s" % dest,
        "cp %s %s/" % (" ".join([s.path for s in ctx.files.srcs]), dest),
        "cd %s" % dir,
        "find . -exec touch -t 198001010000 '{}' ';'",
        "zip -Xqr ../%s *" % ctx.outputs.zip.basename,
    ])

    ctx.actions.run_shell(
        inputs = ctx.files.srcs,
        outputs = [ctx.outputs.zip],
        command = cmd,
        mnemonic = "GenJsComponentZip",
    )

    licenses = []
    if ctx.file.license:
        licenses.append(ctx.file.license)

    return [
        ComponentInfo(
            transitive_licenses = depset(licenses),
            transitive_versions = depset(),
            transitive_zipfiles = list([ctx.outputs.zip]),
        ),
    ]

js_component = rule(
    _js_component,
    attrs = {
        "srcs": attr.label_list(allow_files = [".js"]),
        "license": attr.label(allow_single_file = True),
    },
    outputs = {
        "zip": "%{name}.zip",
    },
)
