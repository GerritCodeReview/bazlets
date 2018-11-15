# Gerrit Code Review Rules for Bazel

<div class="toc">
  <h2>Rules</h2>
  <ul>
    <li><a href="#gerrit_plugin">gerrit_plugin</a></li>
  </ul>
</div>

## Overview

These build rules are used for building [Gerrit Code Review](https://www.gerritcodereview.com/)
plugins with Bazel. Plugins are compiled as `.jar` files containing plugin code and
dependencies.

<a name="setup"></a>
## Setup

To be able to use the Gerrit rules, you must provide bindings for the plugin
API jars. The easiest way to do so is to add the following to your `WORKSPACE`
file, which will give you default versions for Gerrit plugin API.

```python
git_repository(
  name = "com_github_davido_bazlets",
  remote = "https://github.com/davido/bazlets.git",
  commit = "2ede19cb2d2dd9d04bcb70ffc896439a27e5d50d",
)
load("@com_github_davido_bazlets//:gerrit_api.bzl",
     "gerrit_api")
```

Another option is to consume snapshot version of gerrit plugin API from local
Maven repository (`~/.m2`). To use the snapshot version special method is
provided:

```python
load("@com_googlesource_gerrit_bazlets//:gerrit_api_maven_local.bzl",
     "gerrit_api_maven_local")
gerrit_api_maven_local()
```

<a name="basic-example"></a>
## Basic Example

Suppose you have the following directory structure for a simple plugin:

```
[workspace]/
    WORKSPACE
	BUILD
    src/main/java/
	src/main/resources/
	[...]
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
