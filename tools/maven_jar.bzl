# Copyright (C) 2016 The Android Open Source Project
# Copyright (C) 2023 Serge 'q3k' Bazanski
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

load(":base64.bzl", "hex_to_b64")

ECLIPSE = "ECLIPSE:"

GERRIT = "GERRIT:"

GERRIT_API = "GERRIT_API:"

MAVEN_CENTRAL = "MAVEN_CENTRAL:"

MAVEN_LOCAL = "MAVEN_LOCAL:"

REPO_ROOTS = {
  'GERRIT': 'https://gerrit-maven.storage.googleapis.com',
  'GERRIT_API': 'https://gerrit-api.commondatastorage.googleapis.com/release',
  'MAVEN_CENTRAL': 'https://repo1.maven.org/maven2',
  'MAVEN_SNAPSHOT': 'https://oss.sonatype.org/content/repositories/snapshots',
}

def _sha1_to_integrity(ctx, sha1):
    """
    Convert a hex-encoded SHA1 hash into a Subresource Integrity format, as
    used by repository_ctx.download.
    """
    b64 = hex_to_b64(sha1)
    return "sha1-" + b64

def _resolve_url(url):
    """
    Resolve URL of a Maven artifact.  prefix:path is passed as URL. prefix
    identifies known or custom repositories.

    A special case is supported, when prefix doesn't exists in REPO_ROOTS: the
    url is returned as is.  This enables plugins to pass custom
    maven_repository URL as is directly to maven_jar().

    Returns a resolved path for Maven artifact.
    """
    s = url.find(':')
    if s < 0:
      return url
    scheme, rest = url[:s], url[s+1:]
    if scheme in REPO_ROOTS:
      root = REPO_ROOTS[scheme]
    else:
      return url
    root = root.rstrip('/')
    rest = rest.lstrip('/')
    return '/'.join([root, rest])

def _download_hashed(ctx, url, output, src):
    """
    Download a URL and check against source/binary hashes in the given ctx.

    Returns a dictionary of 'fixups' that can be used to indicate to the rule
    instantiator on how the rule should be reconfigured to be hermetic. Here,
    we return only the 'src_sha256' and 'sha256' keys if applicable.
    """
    sha1 = ctx.attr.src_sha1 if src else ctx.attr.sha1
    sha256 = ctx.attr.src_sha256 if src else ctx.attr.sha256
    integrity = ''

    if sha1 != '' and sha256 == '':
        integrity = _sha1_to_integrity(ctx, sha1)
    dl = ctx.download(
        url = url,
        output = output,
        integrity = integrity,
        sha256 = sha256,
    )
    if sha1 == '' and sha256 == '':
        # Notify the user that sha256 should be set.
        if src:
            return {'src_sha256': dl.sha256}
        else:
            return {'sha256': dl.sha256}
    return {}

def _maven_release(ctx, parts):
    """induce jar and url name from maven coordinates."""
    if len(parts) not in [3, 4]:
        fail('%s:\nexpected id="groupId:artifactId:version[:classifier]"' %
             ctx.attr.artifact)
    if len(parts) == 4:
        group, artifact, version, classifier = parts
        file_version = version + "-" + classifier
    else:
        group, artifact, version = parts
        file_version = version

    jar = artifact.lower() + "-" + file_version
    url = "/".join([
        ctx.attr.repository,
        group.replace(".", "/"),
        artifact,
        version,
        artifact + "-" + file_version,
    ])

    return jar, url

# Creates a struct containing the different parts of an artifact's FQN
def _create_coordinates(fully_qualified_name):
    parts = fully_qualified_name.split(":")
    packaging = None
    classifier = None

    if len(parts) == 3:
        group_id, artifact_id, version = parts
    elif len(parts) == 4:
        group_id, artifact_id, version, packaging = parts
    elif len(parts) == 5:
        group_id, artifact_id, version, packaging, classifier = parts
    else:
        fail("Invalid fully qualified name for artifact: %s" % fully_qualified_name)

    return struct(
        fully_qualified_name = fully_qualified_name,
        group_id = group_id,
        artifact_id = artifact_id,
        packaging = packaging,
        classifier = classifier,
        version = version,
    )

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
        rule_name = ctx.name,
        filename = filename,
        deps = _format_deps("deps", ctx.attr.deps),
        exports = _format_deps("exports", ctx.attr.exports),
    )
    ctx.file("%s/BUILD" % ctx.path(classifier), contents, False)

def _maven_jar_impl(ctx):
    """rule to download a Maven archive."""
    coordinates = _create_coordinates(ctx.attr.artifact)

    name = ctx.name

    parts = ctx.attr.artifact.split(":")

    # TODO(davido): Only releases for now, implement handling snapshots
    jar, url = _maven_release(ctx, parts)

    binjar = jar + ".jar"
    binjar_path = ctx.path("/".join(["jar", binjar]))
    binurl = url + ".jar"

    srcjar = jar + "-src.jar"
    srcjar_path = ctx.path("/".join(["src", srcjar]))
    srcurl = url + "-sources.jar"

    sha256 = ctx.attr.sha256
    sha1 = ctx.attr.sha1
    integrity = ''
    if sha1 != '' and sha256 == '':
        integrity = _sha1_to_integrity(ctx, sha1)

    fixup = {}
    fixup.update(_download_hashed(
        ctx = ctx,
        url = _resolve_url(binurl),
        output = "jar/" + binjar,
        src = False,
     ))
    _generate_build_file(ctx, "jar", binjar)

    if ctx.attr.attach_source:
        fixup.update(_download_hashed(
            ctx = ctx,
            url = _resolve_url(srcurl),
            output = "src/" + srcjar,
            src = True,
         ))
        _generate_build_file(ctx, "src", srcjar)

    # Notify user about fixup to attributes for hermeticity.
    ret = {'name': ctx.attr.name}
    for key in _maven_jar_attrs.keys():
        if getattr(ctx.attr, key) != None:
            ret[key] = getattr(ctx.attr, key)
    ret.update(fixup)
    return ret

_maven_jar_attrs = {
    "artifact": attr.string(mandatory = True),
    "attach_source": attr.bool(default = True),
    "exclude": attr.string_list(),
    "repository": attr.string(default = MAVEN_CENTRAL),
    "sha1": attr.string(),
    "sha256": attr.string(),
    "src_sha1": attr.string(),
    "src_sha256": attr.string(),
    "exports": attr.string_list(),
    "deps": attr.string_list(),
}

maven_jar = repository_rule(
    attrs = _maven_jar_attrs,
    local = True,
    implementation = _maven_jar_impl,
)
