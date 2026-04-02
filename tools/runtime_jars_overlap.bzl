load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools:java_runtime_jars_manifest.bzl", "java_runtime_jars_manifest")

def runtime_jars_overlap_test(
        name,
        target,
        against,
        normalize = True,
        exclude_self = True,
        size = "small",
        hint = "",
        **kwargs):
    """Fail if `target`'s runtime jar IDs overlap with `against` list.

    Args:
      name: sh_test name.
      target: Java target providing JavaInfo (e.g. ":myplugin__plugin").
      against: label of a generated text manifest (e.g. "//:release.war.jars.txt").
      normalize/exclude_self: controls jar ID normalization and self-jar exclusion.
      hint: optional help printed on failure.
      **kwargs: forwarded to sh_test (e.g. tags, target_compatible_with).
    """
    plugin_manifest = name + "_manifest"

    java_runtime_jars_manifest(
        name = plugin_manifest,
        target = target,
        normalize = normalize,
        exclude_self = exclude_self,
    )

    args = [
        "$(location :%s.txt)" % plugin_manifest,
        "$(location %s)" % against,
    ]
    if hint:
        args.append(hint)

    sh_test(
        name = name,
        size = size,
        srcs = ["@com_googlesource_gerrit_bazlets//tools:diff_overlap.sh"],
        args = args,
        data = [
            ":%s.txt" % plugin_manifest,
            against,
        ],
        **kwargs
    )
