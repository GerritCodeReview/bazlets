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

# Port of Buck native gwt_binary() rule. See discussion in context of
# https://github.com/facebook/buck/issues/109

load("//maven:defs.bzl", "MAVEN_CENTRAL")

def _maven_release(artifact, repository=MAVEN_CENTRAL):
    """induce jar and url name from maven coordinates."""
    parts = artifact.split(":")
    if len(parts) not in [3, 4]:
        fail('%s:\nexpected id="groupId:artifactId:version[:classifier]"' %
             artifact)
    if len(parts) == 4:
        group, artifact, version, classifier = parts
        file_version = version + "-" + classifier
    else:
        group, artifact, version = parts
        file_version = version

    jar = artifact.lower() + "-" + file_version
    url = "/".join([
        repository,
        group.replace(".", "/"),
        artifact,
        version,
        artifact + "-" + file_version,
    ])

    return jar, url

def _format_deps(attr, deps):
    formatted_deps = ""
    if deps:
        if len(deps) == 1:
            formatted_deps = formatted_deps + "%s = [\'%s\']," % (attr, deps[0])
        else:
            formatted_deps = formatted_deps + "%s = [\n" % attr
            for dep in deps:
                formatted_deps = formatted_deps + "        \'%s\',\n" % dep
            formatted_deps = formatted_deps + "    ],"
    return formatted_deps

# Provides the syntax "@jar_name//jar" for bin classifier
# and "@jar_name//src" for sources
def _generate_build_file(ctx, classifier, filename):
    contents = """
# DO NOT EDIT: automatically generated BUILD file for maven_jar rule {rule_name}
java_import(
    name = '{classifier}',
    jars = ['{filename}'],
    visibility = ['//visibility:public'],
    {deps}
    {exports}
)
java_import(
    name = 'neverlink',
    jars = ['{filename}'],
    neverlink = 1,
    visibility = ['//visibility:public'],
    {deps}
    {exports}
)
filegroup(
    name = 'file',
    srcs = ['{filename}'],
    visibility = ['//visibility:public']
)\n""".format(
        classifier = classifier,
        rule_name = ctx.attr.name,
        filename = filename,
        deps = _format_deps("deps", ctx.attr.deps),
        exports = _format_deps("exports", ctx.attr.exports),
    )
    ctx.file("%s/BUILD" % ctx.path(classifier), contents, False)

def _maven_jar_impl(ctx):
    # TODO(davido): Only releases for now, implement handling snapshots
    jar, url = _maven_release(ctx.attr.artifact, ctx.attr.repository)

    binjar = jar + ".jar"
    binjar_path = ctx.path("/".join(["jar", binjar]))
    binurl = url + ".jar"

    srcjar = jar + "-src.jar"
    srcjar_path = ctx.path("/".join(["src", srcjar]))
    srcurl = url + "-sources.jar"

    python = ctx.which("python3")
    script = ctx.path(ctx.attr._download_script)

    args = [python, script, "-o", binjar_path, "-u", binurl]
    if ctx.attr.sha1:
        args.extend(["-v", ctx.attr.sha1])
    for x in ctx.attr.exclude:
        args.extend(["-x", x])

    out = ctx.execute(args)

    if out.return_code:
        fail("failed %s: %s" % (args, out.stderr))
    _generate_build_file(ctx, "jar", binjar)

    if ctx.attr.src_sha1 or ctx.attr.attach_source:
        args = [python, script, "-o", srcjar_path, "-u", srcurl]
        if ctx.attr.src_sha1:
            args.extend(["-v", ctx.attr.src_sha1])
        out = ctx.execute(args)
        if out.return_code:
            fail("failed %s: %s" % (args, out.stderr))
        _generate_build_file(ctx, "src", srcjar)

maven_jar = repository_rule(
    attrs = {
        "artifact": attr.string(mandatory = True),
        "attach_source": attr.bool(default = True),
        "exclude": attr.string_list(),
        "repository": attr.string(default = MAVEN_CENTRAL),
        "sha1": attr.string(mandatory = False),
        "src_sha1": attr.string(),
        "exports": attr.string_list(),
        "deps": attr.string_list(),
        "_download_script": attr.label(default = Label("//maven/private:download_file.py")),
    },
    local = True,
    implementation = _maven_jar_impl,
)

def _maven_collection_impl(ctx):
    for name, jar in ctx.attr.jars.items():
        rules = """
# DO NOT EDIT: automatically generated BUILD file for maven_collection rule
java_import(
    name = "jar",
    jars = ["{jar}"],
    visibility = ["//visibility:public"],
)

java_import(
    name = "neverlink",
    jars = ["{jar}"],
    neverlink = True,
    visibility = ["//visibility:public"],
)
""".format(jar = jar)
        ctx.file("%s/BUILD" % ctx.path("%s/jar" % name), rules, False)

maven_collection = repository_rule(
    attrs = {
      "jars": attr.string_keyed_label_dict(mandatory = True),
    },
    local = True,
    implementation = _maven_collection_impl,
)
