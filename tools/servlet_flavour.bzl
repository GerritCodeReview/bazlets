"""Servlet-flavour toolchain: resolve the flavour's servlet tier by config.

Makes the servlet flavour a *resolved toolchain* rather than a `select()`
repeated at every boundary. The `//flags:flavour` build setting selects which
registered `servlet_flavour_toolchain` Bazel resolves -- each toolchain gates
itself with `target_settings = ["//flags:<flavour>"]` -- and the resolved
`ServletFlavourInfo` carries that flavour's servlet tier.

INVARIANT: every registered flavour toolchain must resolve the WHOLE servlet
tier (all `ServletFlavourInfo` fields). `servlet_flavour_deps` exposes one field
at a time, but a flavour is only well-formed if it can supply the entire tier.
If per-field independence is ever needed, split into smaller toolchain types
rather than letting a flavour supply a partial tier.

Scope of "adding a flavour is cheap": for the *dependency-set* boundaries this
toolchain backs, a new flavour is one `config_setting` + one `toolchain()`
registration, with no consumer change. Plugin *source-transform* support is
separate and still carries explicit per-flavour logic (the `//flags:flavour`
value list, `gerrit_plugin`'s flavour validation, and the `flavour == "ee11"`
transform branch), so it is not O(1) yet.
"""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")

ServletFlavourInfo = provider(
    doc = "The active servlet flavour's servlet tier, resolved by configuration.",
    fields = {
        "flavour": "flavour name, e.g. \"ee8\" or \"ee11\"",
        "servlet_api": "JavaInfo of the flavour's neverlink servlet API",
        "servlet_api_default": "DefaultInfo of the flavour's neverlink servlet API",
        "servlet_api_runtime": "JavaInfo of the flavour's non-neverlink servlet API",
        "servlet_api_runtime_default": "DefaultInfo of the flavour's non-neverlink servlet API",
        "jetty": "JavaInfo of the flavour's Jetty servlet tier",
        "jetty_default": "DefaultInfo of the flavour's Jetty servlet tier",
        "guice": "JavaInfo of the flavour's Guice core library",
        "guice_default": "DefaultInfo of the flavour's Guice core library",
        "guice_assistedinject": "JavaInfo of the flavour's Guice assistedinject extension",
        "guice_assistedinject_default": "DefaultInfo of the flavour's Guice assistedinject extension",
        "guice_servlet": "JavaInfo of the flavour's Guice servlet extension",
        "guice_servlet_default": "DefaultInfo of the flavour's Guice servlet extension",
        "jgit_servlet": "JavaInfo of the flavour's JGit servlet module",
        "jgit_servlet_default": "DefaultInfo of the flavour's JGit servlet module",
        "gitiles_servlet": "JavaInfo of the flavour's Gitiles servlet jar",
        "gitiles_servlet_default": "DefaultInfo of the flavour's Gitiles servlet jar",
    },
)

_TOOLCHAIN_TYPE = "//flags:servlet_flavour_toolchain_type"

def _servlet_flavour_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        servlet_flavour = ServletFlavourInfo(
            flavour = ctx.attr.flavour,
            servlet_api = ctx.attr.servlet_api[JavaInfo],
            servlet_api_default = ctx.attr.servlet_api[DefaultInfo],
            servlet_api_runtime = ctx.attr.servlet_api_runtime[JavaInfo],
            servlet_api_runtime_default = ctx.attr.servlet_api_runtime[DefaultInfo],
            jetty = ctx.attr.jetty[JavaInfo],
            jetty_default = ctx.attr.jetty[DefaultInfo],
            guice = ctx.attr.guice[JavaInfo],
            guice_default = ctx.attr.guice[DefaultInfo],
            guice_assistedinject = ctx.attr.guice_assistedinject[JavaInfo],
            guice_assistedinject_default = ctx.attr.guice_assistedinject[DefaultInfo],
            guice_servlet = ctx.attr.guice_servlet[JavaInfo],
            guice_servlet_default = ctx.attr.guice_servlet[DefaultInfo],
            jgit_servlet = ctx.attr.jgit_servlet[JavaInfo],
            jgit_servlet_default = ctx.attr.jgit_servlet[DefaultInfo],
            gitiles_servlet = ctx.attr.gitiles_servlet[JavaInfo],
            gitiles_servlet_default = ctx.attr.gitiles_servlet[DefaultInfo],
        ),
    )]

servlet_flavour_toolchain = rule(
    implementation = _servlet_flavour_toolchain_impl,
    doc = "One flavour's whole servlet tier; register via `toolchain()` gated on //flags:<flavour>.",
    attrs = {
        "flavour": attr.string(mandatory = True, doc = "Flavour name, e.g. \"ee11\"."),
        "servlet_api": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "The flavour's neverlink servlet-api target.",
        ),
        "servlet_api_runtime": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "The flavour's non-neverlink servlet-api target (bundled in the WAR).",
        ),
        "jetty": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "The flavour's Jetty servlet tier target.",
        ),
        "guice": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "The flavour's Guice core target.",
        ),
        "guice_assistedinject": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "The flavour's Guice assistedinject extension target.",
        ),
        "guice_servlet": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "The flavour's Guice servlet extension target.",
        ),
        "jgit_servlet": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "The flavour's JGit servlet module target.",
        ),
        "gitiles_servlet": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "The flavour's Gitiles servlet jar target.",
        ),
    },
)

def _servlet_flavour_deps_impl(ctx):
    # Re-export ONE part of the toolchain-resolved flavour tier as a plain
    # JavaInfo target, so a java_library / macro / BUILD can `deps = [":<this>"]`
    # and get the active flavour's servlet-api / Jetty / Guice / JGit jar on its
    # compile classpath -- WITHOUT reading ctx.toolchains (which macros cannot)
    # and without select(). This is the bridge from toolchain resolution into
    # label-land that backs the build.
    b = ctx.toolchains[_TOOLCHAIN_TYPE].servlet_flavour
    parts = {
        "servlet_api": [b.servlet_api, b.servlet_api_default],
        "servlet_api_runtime": [b.servlet_api_runtime, b.servlet_api_runtime_default],
        "jetty": [b.jetty, b.jetty_default],
        "guice": [b.guice, b.guice_default],
        "guice_assistedinject": [b.guice_assistedinject, b.guice_assistedinject_default],
        "guice_servlet": [b.guice_servlet, b.guice_servlet_default],
        "jgit_servlet": [b.jgit_servlet, b.jgit_servlet_default],
        "gitiles_servlet": [b.gitiles_servlet, b.gitiles_servlet_default],
    }
    return parts[ctx.attr.part]

servlet_flavour_deps = rule(
    implementation = _servlet_flavour_deps_impl,
    doc = "Resolver: exposes ONE part of the active flavour's servlet tier as a JavaInfo dep.",
    toolchains = [_TOOLCHAIN_TYPE],
    provides = [JavaInfo],
    attrs = {
        "part": attr.string(
            mandatory = True,
            values = [
                "servlet_api",
                "servlet_api_runtime",
                "jetty",
                "guice",
                "guice_assistedinject",
                "guice_servlet",
                "jgit_servlet",
                "gitiles_servlet",
            ],
            doc = "Which part of the flavour's servlet tier to expose.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Query-visible license/data edges for generated license maps.",
        ),
        "license_deps": attr.label_list(
            doc = "Concrete license-bearing deps visible to unconfigured query.",
        ),
    },
)
