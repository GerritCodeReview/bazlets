"""Generate CycloneDX SBOMs for Java libraries, plugins and packaged WARs.

The aspect collects Maven identities and original artifact hashes from
rules_jvm_external. A packaged-JAR manifest, or JavaInfo for a library, selects
which dependencies ship. The same generator serves Gerrit, Gitiles and plugins.
"""

load("@rules_java//java:defs.bzl", "JavaInfo")

SbomInfo = provider(
    doc = "Maven nodes collected from a target's dependency closure.",
    fields = {
        "coord": "this target's maven coordinate, or None if not a jvm_import",
        "nodes": "depset of struct(label, coord, sha256, deps) over the closure",
    },
)

# Same prefix rules_jvm_external uses for stamped jars.
_PROCESSED_PREFIX = "processed_"

def _tag(tags, prefix):
    for t in tags:
        if t.startswith(prefix):
            return t[len(prefix):]
    return None

def _attr_targets(value):
    """Flatten a rule attribute value to the Targets it points at."""
    if type(value) == "Target":
        return [value]
    if type(value) == type([]):
        return [v for v in value if type(v) == "Target"]
    if type(value) == type({}):
        out = []
        for k, v in value.items():
            for entry in (k, v):
                if type(entry) == "Target":
                    out.append(entry)
                elif type(entry) == type([]):
                    out.extend([i for i in entry if type(i) == "Target"])
        return out
    return []

def _sbom_aspect_impl(target, ctx):
    tags = getattr(ctx.rule.attr, "tags", None) or []
    coord = _tag(tags, "maven_coordinates=")
    sha256 = _tag(tags, "maven_sha256=")

    # Follow every attribute to reach what deps() does, including annotation
    # processors pulled in only via plugins. Dedup by label.
    transitive = []
    direct_dep_coords = []
    seen = {}
    for name in dir(ctx.rule.attr):
        for dep in _attr_targets(getattr(ctx.rule.attr, name)):
            if SbomInfo not in dep:
                continue
            key = str(dep.label)
            if key in seen:
                continue
            seen[key] = True
            transitive.append(dep[SbomInfo].nodes)
            if dep[SbomInfo].coord:
                direct_dep_coords.append(dep[SbomInfo].coord)

    direct = []
    if coord:
        direct.append(struct(
            label = str(target.label),
            coord = coord,
            sha256 = sha256 if sha256 else "",
            # Tuple, not list: depset elements must be immutable.
            deps = tuple(direct_dep_coords),
        ))

    return [SbomInfo(
        coord = coord,
        nodes = depset(direct = direct, transitive = transitive),
    )]

_sbom_aspect = aspect(
    implementation = _sbom_aspect_impl,
    attr_aspects = ["*"],
    provides = [SbomInfo],
    apply_to_generating_rules = True,
)

def _sbom_impl(ctx):
    t = ctx.attr.target
    nodes = t[SbomInfo].nodes.to_list()

    facts = ctx.actions.declare_file(ctx.label.name + ".graph.json")
    ctx.actions.write(
        output = facts,
        content = json.encode([
            {
                "label": n.label,
                "coord": n.coord,
                "sha256": n.sha256,
                "deps": list(n.deps),
            }
            for n in nodes
        ]),
    )

    out = ctx.actions.declare_file(ctx.label.name + ".cyclonedx.json")
    args = ctx.actions.args()
    args.add("--graph-facts", facts)
    args.add("--output", out)
    args.add("--target", str(t.label))
    args.add("--product-name", ctx.attr.product_name if ctx.attr.product_name else ctx.label.name)
    args.add("--product-group", ctx.attr.product_group)
    args.add("--product-version", ctx.attr.version)
    if ctx.file.version_file:
        args.add("--product-version-file", ctx.file.version_file)
    args.add("--property-namespace", ctx.attr.namespace)
    if not ctx.attr.include_compile_only:
        # A plugin SBOM omits the Gerrit-provided Plugin API closure
        # (compile-only here) -- it is already in gerrit.war's own SBOM.
        args.add("--drop-compile-only")
    inputs = [facts]
    if ctx.file.version_file:
        inputs.append(ctx.file.version_file)

    # WAR rules expose the manifest after applying packaging exclusions.
    # Callers with another packaging rule can supply the same manifest directly.
    shipped = ctx.file.shipped_labels
    if not shipped and OutputGroupInfo in t:
        outputs = t[OutputGroupInfo]
        if hasattr(outputs, "sbom_shipped_labels"):
            shipped = outputs.sbom_shipped_labels.to_list()[0]
    if shipped:
        args.add("--shipped-labels", shipped)
        inputs.append(shipped)
    elif JavaInfo in t:
        self_jars = {f.path: None for f in t[JavaInfo].runtime_output_jars}
        lines = []
        for f in t[JavaInfo].transitive_runtime_jars.to_list():
            if f.path in self_jars:
                continue
            name = f.basename
            if name.startswith(_PROCESSED_PREFIX):
                name = name[len(_PROCESSED_PREFIX):]
            lines.append("%s\t%s" % (name, f.owner))
        shipped = ctx.actions.declare_file(ctx.label.name + ".shipped.txt")
        ctx.actions.write(
            output = shipped,
            content = "\n".join(sorted(lines)) + "\n",
        )
        args.add("--shipped-labels", shipped)
        inputs.append(shipped)

    ctx.actions.run(
        executable = ctx.executable._generator,
        arguments = [args],
        inputs = inputs,
        outputs = [out],
        mnemonic = "Sbom",
        progress_message = "Generating SBOM %s" % ctx.label,
    )
    return [DefaultInfo(files = depset([out]))]

sbom = rule(
    implementation = _sbom_impl,
    doc = "CycloneDX 1.7 SBOM for a target's Maven dependency closure.",
    attrs = {
        "target": attr.label(
            mandatory = True,
            aspects = [_sbom_aspect],
            doc = "target whose dependency closure is described",
        ),
        "version": attr.string(
            default = "0",
            doc = "product version string for the root component",
        ),
        "version_file": attr.label(
            allow_single_file = True,
            doc = "optional product version file; takes precedence over version",
        ),
        "shipped_labels": attr.label(
            allow_single_file = True,
            doc = "optional manifest of packaged path<TAB>producing target label",
        ),
        "product_name": attr.string(default = ""),
        "product_group": attr.string(default = "com.googlesource.gerrit.plugins"),
        "namespace": attr.string(default = "gerrit"),
        "include_compile_only": attr.bool(
            default = False,
            doc = "include build-time dependencies in addition to packaged jars. " +
                  "Off for plugins to omit the Gerrit-provided API closure.",
        ),
        "_generator": attr.label(
            default = "//tools:sbom_from_graph",
            executable = True,
            cfg = "exec",
        ),
    },
)
