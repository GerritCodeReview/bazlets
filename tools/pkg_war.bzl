# Copyright (C) 2016 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# War packaging.

load("@rules_java//java:defs.bzl", "JavaInfo")

jar_filetype = [".jar"]

# Special prefix added by rules_jvm_external.jvm_import() to stamped jars
# https://github.com/bazel-contrib/rules_jvm_external/blob/6.9/private/rules/jvm_import.bzl#L32
PROCESSED_PREFIX = "processed_"

def _add_context(in_file, output):
    input_path = in_file.path
    return [
        "unzip -qd %s %s" % (output, input_path),
    ]

def _add_file(in_file, output):
    output_path = output
    input_path = in_file.path
    short_path = in_file.short_path
    n = in_file.basename

    if n != "web.xml" and short_path.startswith("java/"):
        n = short_path[5:].replace("/", "_")

    if n.startswith(PROCESSED_PREFIX):
        n = n[len(PROCESSED_PREFIX):]

    output_path += n
    return [
        "test -L %s || ln -s $(pwd)/%s %s" % (output_path, input_path, output_path),
    ]

def _make_war(input_dir, output):
    return "(%s)" % " && ".join([
        "root=$(pwd)",
        "cd %s" % input_dir,
        "find . -exec touch -t 198001010000 '{}' ';' 2> /dev/null",
        "zip -X -9qr ${root}/%s ." % (output.path),
    ])

def _war_impl(ctx):
    war = ctx.outputs.war
    build_output = war.path + ".build_output"
    inputs = []

    # Create war layout
    cmd = [
        "set -e;rm -rf " + build_output,
        "mkdir -p " + build_output,
        "mkdir -p %s/WEB-INF/lib" % build_output,
        "mkdir -p %s/WEB-INF/pgm-lib" % build_output,
    ]

    # Add lib
    transitive_libs = []
    for l in ctx.attr.libs:
        if JavaInfo in l:
            transitive_libs.append(l[JavaInfo].transitive_runtime_jars)
        elif hasattr(l, "files"):
            transitive_libs.append(l.files)

    transitive_lib_deps = depset(transitive = transitive_libs)
    for dep in transitive_lib_deps.to_list():
        if dep.basename.startswith("auto-value-") or dep.basename.startswith("auto-factory-"):
            continue
        cmd += _add_file(dep, build_output + "/WEB-INF/lib/")
        inputs.append(dep)

    # Add pgm lib
    transitive_pgmlibs = []
    for l in ctx.attr.pgmlibs:
        transitive_pgmlibs.append(l[JavaInfo].transitive_runtime_jars)

    transitive_pgmlib_deps = depset(transitive = transitive_pgmlibs)
    for dep in transitive_pgmlib_deps.to_list():
        if dep.basename.startswith("auto-value-") or dep.basename.startswith("auto-factory-"):
            continue
        if dep not in inputs:
            cmd += _add_file(dep, build_output + "/WEB-INF/pgm-lib/")
            inputs.append(dep)

    # Add context
    transitive_context_libs = []
    if ctx.attr.context:
        for jar in ctx.attr.context:
            if JavaInfo in jar:
                transitive_context_libs.append(jar[JavaInfo].transitive_runtime_jars)
            elif hasattr(jar, "files"):
                transitive_context_libs.append(jar.files)

    transitive_context_deps = depset(transitive = transitive_context_libs)
    for dep in transitive_context_deps.to_list():
        cmd += _add_context(dep, build_output)
        inputs.append(dep)

    # Add zip war
    cmd.append(_make_war(build_output, war))

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = [war],
        mnemonic = "WAR",
        command = "\n".join(cmd),
        use_default_shell_env = True,
    )

# context: go to the root directory
# libs: go to the WEB-INF/lib directory
# pgmlibs: go to the WEB-INF/pgm-lib directory
# web_xml: go to the WEB-INF directory
_pkg_war = rule(
    attrs = {
        "context": attr.label_list(allow_files = True),
        "libs": attr.label_list(allow_files = jar_filetype),
        "pgmlibs": attr.label_list(allow_files = False),
        "web_xml": attr.label(allow_files = True),
    },
    outputs = {"war": "%{name}.war"},
    implementation = _war_impl,
)

def pkg_war(name, context = [], **kwargs):
    _pkg_war(
        name = name,
        context = context,
        **kwargs
    )
