load("@rules_java//java:defs.bzl", "JavaInfo")

# Same prefix used by rules_jvm_external for stamped jars.
_PROCESSED_PREFIX = "processed_"

def _strip_processed_prefix(name):
    if name.startswith(_PROCESSED_PREFIX):
        return name[len(_PROCESSED_PREFIX):]
    return name

def _normalize_jar_id(jar_name):
    # jar_name is expected WITHOUT ".jar" (we're using basenames), but handle it anyway.
    n = jar_name
    if n.endswith(".jar"):
        n = n[:-4]

    # Strip a trailing "-<version-ish>" where the suffix begins with a digit.
    # This is intentionally conservative: it avoids stripping "-api" and similar,
    # but it may leave additional qualifiers (e.g. "-1.2.3-jre").
    i = n.rfind("-")
    if i > 0 and n[i + 1:i + 2].isdigit():
        n = n[:i]
    return n

def _java_runtime_jars_manifest_impl(ctx):
    t = ctx.attr.target
    if JavaInfo not in t:
        fail("Target %s does not provide JavaInfo" % t.label)

    jars = [f.basename for f in t[JavaInfo].transitive_runtime_jars.to_list()]

    # Optionally drop the target's own output jar(s) from the inventory.
    if ctx.attr.exclude_self:
        self_jars = [f.basename for f in t[JavaInfo].runtime_output_jars]
        jars = [j for j in jars if j not in self_jars]

    # Strip rules_jvm_external stamping prefix for stable naming.
    jars = [_strip_processed_prefix(j) for j in jars]

    if ctx.attr.normalize:
        jars = [_normalize_jar_id(j) for j in jars]

    jars = sorted(depset(jars).to_list())

    ctx.actions.write(
        output = ctx.outputs.out,
        content = "\n".join(jars) + "\n",
    )
    return DefaultInfo(files = depset([ctx.outputs.out]))

java_runtime_jars_manifest = rule(
    implementation = _java_runtime_jars_manifest_impl,
    attrs = {
        # Java target (must provide JavaInfo) to create a runtime JAR manifest for.
        "target": attr.label(mandatory = True),
        # If True, emit version-agnostic IDs (recommended for allowlists).
        "normalize": attr.bool(default = True),
        # If True, exclude the target's own output jar(s) from the manifest.
        "exclude_self": attr.bool(default = True),
    },
    outputs = {"out": "%{name}.txt"},
)
