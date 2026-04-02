load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools:java_runtime_jars_manifest.bzl", "java_runtime_jars_manifest")

def runtime_jars_allowlist_test(
        name,
        target,
        allowlist,
        normalize = True,
        exclude_self = True,
        size = "small",
        hint = ""):
    """Create a runtime-JAR manifest and a test that diffs it against an allowlist.

    Args:
      name: Name of the sh_test to create.
      target: Java target label providing JavaInfo (e.g. ":myplugin__plugin").
      allowlist: Allowlist file label (e.g. ":myplugin_third_party_runtime_jars.allowlist.txt").
      normalize: If True, strip version suffixes from JAR basenames for stable allowlists.
      exclude_self: If True, exclude the target's own output jar(s) from the manifest.
      size: Bazel test size ("small", "medium", ...).
      hint: Optional string printed in failure output to help refresh the allowlist.
    """
    manifest_name = name + "_manifest"

    java_runtime_jars_manifest(
        name = manifest_name,
        target = target,
        normalize = normalize,
        exclude_self = exclude_self,
    )

    args = [
        "$(location %s)" % allowlist,
        "$(location :%s.txt)" % manifest_name,
    ]
    if hint:
        args.append(hint)

    sh_test(
        name = name,
        size = size,
        srcs = ["@com_googlesource_gerrit_bazlets//tools:diff_allowlist.sh"],
        args = args,
        data = [
            allowlist,
            ":%s.txt" % manifest_name,
        ],
    )
