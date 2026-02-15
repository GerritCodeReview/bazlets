# Gerrit Code Review Rules for Bazel

<div class="toc">
  <h2>Rules</h2>
  <ul>
    <li><a href="#gerrit_plugin">gerrit_plugin</a></li>
    <li><a href="#runtime_jars_allowlist_test">runtime_jars_allowlist_test</a></li>
    <li><a href="#runtime_jars_overlap_test">runtime_jars_overlap_test</a></li>
  </ul>
</div>

## Overview

These build rules are used for building [Gerrit Code Review](https://www.gerritcodereview.com/)
plugins with Bazel. Plugins are compiled as `.jar` files containing plugin code and
dependencies.

<a name="setup"></a>
## Setup

To be able to use the Gerrit rules, you must provide bindings for the plugin
API jars. The easiest way to do so is to add the following to your `MODULE.bazel`
file, which will give you default versions for Gerrit plugin API.

```python
bazel_dep(name = "com_googlesource_gerrit_bazlets")
git_override(
  module_name = "com_googlesource_gerrit_bazlets",
  remote = "https://gerrit.googlesource.com/bazlets",
  commit = "928c928345646ae958b946e9bbdb462f58dd1384",
)

gerrit_api_version = use_repo_rule(
  "@com_googlesource_gerrit_bazlets//:gerrit_api_version.bzl",
  "gerrit_api_version"
)
gerrit_api_version(
    name = "gerrit_api_version",
    visibility = ["//visibility:public"],
)
```

The `version` parameter allows to override the default API. For release version
numbers:

```python
gerrit_api_version = use_repo_rule(
  "@com_googlesource_gerrit_bazlets//:gerrit_api_version.bzl",
  "gerrit_api_version"
)
gerrit_api_version(
    name = "gerrit_api_version",
    version = "3.11.0",
    visibility = ["//visibility:public"],
)
```

To use a snapshot version of the Gerrit API, clone the `bazlets` repository. Then
add the `file://`-URL to the lis tof repositories in the `MODULE.bazel` file and
adapt the `GERRIT_API_VERSION`-constant, e.g.:

```python
GERRIT_API_VERS = "3.11.0-SNAPSHOT"

maven.install(
    name = "maven",
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
```

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
└── MODULE.bazel
```

To build this plugin, your `BUILD` can look like this:

```python
load("@com_googlesource_gerrit_bazlets//:gerrit_plugin.bzl", "gerrit_plugin")

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
gerrit_plugin(name, srcs, resources, deps, manifest_entries):
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
