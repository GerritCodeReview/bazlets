# Gerrit Code Review Rules for Bazel

<div class="toc">
  <h2>Rules</h2>
  <ul>
    <li><a href="#gerrit_plugin">gerrit_plugin</a></li>
    <li><a href="#runtime_jars_allowlist_test">runtime_jars_allowlist_test</a></li>
    <li><a href="#runtime_jars_overlap_test">runtime_jars_overlap_test</a></li>
    <li><a href="#gerrit_tree_only_checks">Gerrit-tree-only checks</a></li>
  </ul>
</div>

## Overview

These build rules are used for building [Gerrit Code Review](https://www.gerritcodereview.com/)
plugins with Bazel. Plugins are compiled as `.jar` files containing plugin code and
dependencies.

<a name="setup"></a>
## Setup

The setup depends on whether the plugin uses the deprecated Bazel WORKSPACE or
has already transitioned to Bazel modules.

### WORKSPACE

To be able to use the Gerrit rules, you must provide bindings for the plugin
API jars. The easiest way to do so is to add the following to your `WORKSPACE`
file, which will give you default versions for Gerrit plugin API.

```python
git_repository(
  name = "com_googlesource_gerrit_bazlets",
  remote = "https://gerrit.googlesource.com/bazlets",
  commit = "928c928345646ae958b946e9bbdb462f58dd1384",
)
load("@com_googlesource_gerrit_bazlets//:gerrit_api.bzl", "gerrit_api")
gerrit_api()
```

The `version` parameter allows to override the default API. For release version
numbers, make sure to also provide artifacts' SHA1 sums via the
`plugin_api_sha1` and `acceptance_framework_sha1` parameters:

```python
load("@com_googlesource_gerrit_bazlets//:gerrit_api.bzl", "gerrit_api")
gerrit_api(version = "3.2.1",
           plugin_api_sha1 = "47019cf43ef7e6e8d2d5c0aeba0407d23c93699c",
           acceptance_framework_sha1 = "6252cab6d1f76202e57858fcffb428424e90b128")
```

If the version ends in `-SNAPSHOT`, the jars are consumed from the local
Maven repository (`~/.m2`) per default assumed to be and the SHA1 sums can be
omitted:

```python
load("@com_googlesource_gerrit_bazlets//:gerrit_api.bzl", "gerrit_api")
gerrit_api(version = "3.3.0-SNAPSHOT")
```

### MODULE.bazel

When using a Bazel module, the plugin will have to install the Gerrit API in its
`MODULE.bazel` itself:

```python
# The name has to be unique
module(name = "gerrit-plugin")

bazel_dep(name = "rules_jvm_external", version = "6.10")
bazel_dep(name = "com_googlesource_gerrit_bazlets")
git_override(
  module_name = "com_googlesource_gerrit_bazlets",
  remote = "https://gerrit.googlesource.com/bazlets",
  commit = "928c928345646ae958b946e9bbdb462f58dd1384",
)

GERRIT_API_VERSION = "3.12.0"

gerrit_api_version = use_repo_rule(
    "@com_googlesource_gerrit_bazlets//:gerrit_api_version.bzl",
    "gerrit_api_version"
)

gerrit_api_version(
    name = "gerrit_api_version",
    version = GERRIT_API_VERSION,
    visibility = ["//visibility:public"],
)

maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven")

maven.install(
    name = "external_plugin_deps",
    artifacts = [
        "com.google.gerrit:gerrit-acceptance-framework:" + GERRIT_API_VERSION,
        "com.google.gerrit:gerrit-plugin-api:" + GERRIT_API_VERSION,
    ],
    duplicate_version_warning = "error",
    fail_if_repin_required = True,
    fail_on_missing_checksum = True,
    fetch_sources = True,
    lock_file = "//:external_plugin_deps.lock.json",
    repositories = [
        "https://repo1.maven.org/maven2",
        "https://gerrit-maven.storage.googleapis.com",
    ],
    version_conflict_policy = "pinned",
)

use_repo(maven, "external_plugin_deps")
```

To use a snapshot version of the Gerrit API, add the `file://`-URL to the list
of repositories in the `MODULE.bazel` file and adapt the `GERRIT_API_VERSION`-
constant, e.g.:

```python
GERRIT_API_VERSION = "3.11.0-SNAPSHOT"

maven.install(
    name = "external_plugin_deps",
    artifacts = [
    ...
    ],
    repositories = [
        "file:///home/user/.m2/repository",
        "https://repo1.maven.org/maven2",
        "https://gerrit-maven.storage.googleapis.com",
    ],
    ...
)

<a name="basic-example"></a>
## Basic Example

Suppose you have the following directory structure for a simple plugin:

```
[workspace]/
├── src
│   └── main
│       ├── java
│       └── resources
├── BUILD
└── WORKSPACE
```

To build this plugin, your `BUILD` can look like this:

```python
load("//tools/bzl:plugin.bzl", "gerrit_plugin")

gerrit_plugin(
    name = "reviewers",
    srcs = glob(["src/main/java/**/*.java"]),
    manifest_entries = [
        "Gerrit-PluginName: reviewers",
        "Gerrit-Module: com.googlesource.gerrit.plugins.reviewers.Module",
    ],
    resources = glob(["src/main/**/*"]),
)
```

Now, you can build the Gerrit plugin by running
`bazel build <plugin>`.

For a real world example, see the
[`reviewers`](https://gerrit.googlesource.com/plugins/reviewers) plugin.

<a name="gerrit_plugin"></a>
## gerrit_plugin

```python
gerrit_plugin(name, srcs, resources, deps, manifest_entries, main_class):
```

### Implicit output target

 * `<name>.jar`: library containing built plugin jar

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>
          List of .java source files that will be compiled.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>resources</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>
          List of resource files that will be passed on the classpath to the Java
          compiler.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>
          List of other java_libraries on which the plugin depends.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>main_class</code></td>
      <td>
        <code>String, optional</code>
        <p>
          Main class for the plugin JAR. Defaults to <code>Dummy</code> for
          regular Gerrit plugins. Plugins that also provide a standalone
          command line entry point can set this so the plugin JAR can be run
          with <code>java -jar</code>.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>manifest_entries</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>
          A list of lines to add to the META-INF/manifest.mf file
		  generated for the *_deploy.jar target.
        </p>
      </td>
    </tr>
  </tbody>
</table>

<a name="runtime_jars_allowlist_test"></a>
## runtime_jars_allowlist_test

This macro helps plugins track the set of third-party runtime dependencies that
would be packaged into the plugin and detect accidental dependency changes in CI.

Example usage in a plugin BUILD file:

```python
    load(
        "@com_googlesource_gerrit_bazlets//tools:runtime_jars_allowlist.bzl",
        "runtime_jars_allowlist_test",
    )

    runtime_jars_allowlist_test(
        name = "check_oauth_third_party_runtime_jars",
        allowlist = ":oauth_third_party_runtime_jars.allowlist.txt",
        hint = ":check_oauth_third_party_runtime_jars_manifest",
        target = ":oauth__plugin",
    )
```

To refresh the allowlist after an expected change:

```bash
    bazelisk build //:check_oauth_third_party_runtime_jars_manifest
    cp bazel-bin/check_oauth_third_party_runtime_jars_manifest.txt \
       oauth_third_party_runtime_jars.allowlist.txt
```

Optional arguments:

- normalize (default: True) — strip version suffixes from jar basenames.
- exclude_self (default: True) — omit the target's own output jar(s).
- size (default: "small") — Bazel test size classification.

<a name="runtime_jars_overlap_test"></a>
## runtime_jars_overlap_test

This macro helps plugins detect accidental bundling of third-party runtime JARs
that are already shipped by Gerrit. It compares the plugin's packaged runtime
JAR list against a provided manifest (for example Gerrit's
`//:release.war.jars.txt`) and fails on overlap.

This check is typically meaningful only when the plugin is built inside the
Gerrit source tree where Gerrit's runtime manifest exists. Standalone plugin
workspaces should gate the test via `target_compatible_with` so it is reported
as **SKIPPED** rather than failing.

Example usage in a plugin BUILD file:

```python
load(
    "@com_googlesource_gerrit_bazlets//tools:runtime_jars_overlap.bzl",
    "runtime_jars_overlap_test",
)
load(
    "@com_googlesource_gerrit_bazlets//tools:in_gerrit_tree.bzl",
    "in_gerrit_tree_enabled",
)

runtime_jars_overlap_test(
    name = "no_overlap_with_gerrit",
    target = ":my_plugin__plugin",
    against = "//:release.war.jars.txt",
    hint = "Exclude overlaps via maven.install(excluded_artifacts=[...]) and re-run this test.",
    target_compatible_with = in_gerrit_tree_enabled(),
)
```

Optional arguments:

- normalize (default: True) — strip version suffixes from jar basenames.
- exclude_self (default: True) — omit the target's own output jar(s).
- size (default: "small") — Bazel test size classification.
- hint (default: "") — optional guidance printed on failure.

On failure, the test prints the overlapping normalized jar IDs and exits
non-zero.

<a name="gerrit_tree_only_checks"></a>
## Gerrit-tree-only checks

Some plugin tests and guardrails are meaningful only when the plugin is built
inside the Gerrit source tree (e.g. checks that compare against
`//:release.war.jars.txt`). Such checks should run when building in-tree, but be
automatically skipped in standalone plugin workspaces.

Bazlets provides a typed Bazel build setting and helper to support this pattern.

### Usage in plugin BUILD files

```python
load(
    "@com_googlesource_gerrit_bazlets//tools:in_gerrit_tree.bzl",
    "in_gerrit_tree_enabled",
)

runtime_jars_overlap_test(
    name = "no_overlap_with_gerrit",
    against = "//:release.war.jars.txt",
    target = ":my_plugin",
    target_compatible_with = in_gerrit_tree_enabled(),
)
```

In the Gerrit source tree, enable these checks by setting the following in
`.bazelrc`:

```
common --@com_googlesource_gerrit_bazlets//flags:in_gerrit_tree=true
```

Standalone plugin workspaces should not set this flag. In that case, the
corresponding targets are marked incompatible and reported as SKIPPED by Bazel.
