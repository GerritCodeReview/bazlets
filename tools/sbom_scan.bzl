"""Reusable SBOM + Trivy-scan wiring for any packaged Bazel target.

sbom_scan() generates a CycloneDX SBOM for a target's dependency closure and
adds an opt-in Bazel test that scans it with Trivy, failing on any CVE. It is
not plugin-specific: point it at a plugin jar, a WAR, or any other packaged
target. gerrit_plugin wires it in automatically for plugins; standalone
archives (for example gitiles) call it directly from their BUILD.
"""

load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools:sbom.bzl", "sbom")

def sbom_scan(name, target, product_name = None, trivyignore = None, **kwargs):
    """Generate <name>_sbom and a <name>_sbom_scan Trivy test.

    Args:
      name: base name; produces <name>_sbom and <name>_sbom_scan.
      target: the packaged target whose dependency closure is described.
      product_name: SBOM product name; defaults to name.
      trivyignore: optional label of a .trivyignore allowlist. When None, a
        .trivyignore next to this BUILD file is picked up automatically if it
        exists; otherwise the scan runs with no suppressions.
      **kwargs: forwarded to the sh_test (for example target_compatible_with).

    The scan is not hermetic: it shells out to a locally installed trivy and
    needs the network for the vulnerability database, so it is tagged manual
    (opt-in), local, external, and no-sandbox. Run with
    bazel test //<package>:<name>_sbom_scan.
    """
    sbom(
        name = name + "_sbom",
        target = target,
        product_name = product_name or name,
    )

    scan_args = ["$(rootpath :%s_sbom)" % name]
    scan_data = [":%s_sbom" % name]

    # Suppressions are per-target, never shared: a .trivyignore next to the
    # BUILD (or an explicit label) lists CVEs that have no upstream fix yet or
    # are not reachable, each with a justification.
    ignore = trivyignore
    if ignore == None:
        found = native.glob([".trivyignore"], allow_empty = True)
        ignore = found[0] if found else None
    if ignore:
        scan_args.append("$(rootpath %s)" % ignore)
        scan_data.append(ignore)

    sh_test(
        name = name + "_sbom_scan",
        srcs = ["@com_googlesource_gerrit_bazlets//tools:trivy_scan.sh"],
        args = scan_args,
        data = scan_data,
        tags = [
            "external",
            "local",
            "manual",
            "no-sandbox",
        ],
        **kwargs
    )
