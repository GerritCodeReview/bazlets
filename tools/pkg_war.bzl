# Copyright (C) 2017 The Android Open Source Project
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

def _add_context(in_file, output):
    input_path = in_file.path
    return [
        "unzip -qd %s %s" % (output, input_path),
    ]

def _add_file(name, in_file, output):
    output_path = output
    input_path = in_file.path
    short_path = in_file.short_path
    n = in_file.basename

    if n != "web.xml" and short_path.startswith("%s-" % name):
        n = short_path.split("/")[0] + "-" + n

    output_path = output_path + n

    return [
        "test -L %s || ln -s $(pwd)/%s %s" % (output_path, input_path, output_path),
    ]

def _make_war(input_dir, output):
    return "(%s)" % " && ".join([
        "root=$(pwd)",
        "cd %s" % input_dir,
        "find . -exec touch -t 198001010000 '{}' ';' 2> /dev/null",
        "zip -9qr ${root}/%s ." % (output.path),
    ])

def _war_impl(ctx):
    war = ctx.outputs.war
    build_output = war.path + ".build_output"
    inputs = []

    cmd = [
        "set -e;rm -rf " + build_output,
        "mkdir -p " + build_output,
        "mkdir -p %s/WEB-INF/lib" % build_output,
    ]

    transitive_libs = []
    for l in ctx.attr.libs:
        if JavaInfo in l:
            transitive_libs.append(l[JavaInfo].transitive_runtime_jars)
        elif hasattr(l, "files"):
            transitive_libs.append(l.files)

    transitive_lib_deps = depset(transitive = transitive_libs)
    for dep in transitive_lib_deps.to_list():
        cmd = cmd + _add_file(ctx.attr.name, dep, build_output + "/WEB-INF/lib/")
        inputs.append(dep)

    if ctx.attr.web_xml:
        for web_xml in ctx.attr.web_xml.files.to_list():
            inputs.append(web_xml)
            cmd = cmd + _add_file(ctx.attr.name, web_xml, build_output + "/WEB-INF/")

    transitive_context_libs = []
    if ctx.attr.context:
        for jar in ctx.attr.context:
            if JavaInfo in jar:
                transitive_context_libs.append(jar[JavaInfo].transitive_runtime_jars)
            elif hasattr(jar, "files"):
                transitive_context_libs.append(jar.files)
    transitive_context_deps = depset(transitive = transitive_context_libs)
    for dep in transitive_context_deps.to_list():
        cmd = cmd + _add_context(dep, build_output)
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
# web_xml: go to the WEB-INF directory
_pkg_war = rule(
    attrs = {
        "context": attr.label_list(allow_files = True),
        "libs": attr.label_list(allow_files = [".jar"]),
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
