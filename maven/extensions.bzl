load("//maven:defs.bzl", "MAVEN_CENTRAL")
load("//maven/private:maven_jar.bzl", "maven_collection", maven_jar_rule = "maven_jar")

MAVEN_REPO = "maven_deps"

def _maven_jar_impl(module_ctx):
  jars = {}
  for mod in module_ctx.modules:
    for attr in mod.tags.install:
      maven_jar_rule(
        name =  attr.name,
        artifact = attr.artifact,
        attach_source = attr.attach_source,
        exclude = attr.exclude,
        repository = attr.repository,
        sha1 = attr.sha1,
        src_sha1 = attr.src_sha1,
        exports = attr.exports,
        deps = attr.deps,
      )
      jars[attr.name] = "@%s//jar:file" % attr.name

  maven_collection(
    name = MAVEN_REPO,
    jars = jars,
  )
  return module_ctx.extension_metadata()

# To use the extension register it in your MODULES.bazel:
#
#   ```
#   bazel_dep(name = "com_googlesource_gerrit_bazlets")
#   maven_jar = use_extension("@com_googlesource_gerrit_bazlets//maven:extensions.bzl", "maven_jar")
#   ```
#
# Then install all required jars, e.g.:
#
#   ```
#   maven_jar.install(
#    name = "gitiles-servlet",
#    artifact = "com.google.gitiles:gitiles-servlet:" + GITILES_VERS,
#    repository = GITILES_REPO,
#    sha1 = "52441c05b83291898da051591036d0d55e1f3501",
#   )
#   ```
#
# This can be done multiple times to add multiple JARs. Afterwards, register the
# repository:
#
#   ```
#   use_repo(maven_jar, "maven_deps")
#   ```
#
# To reference a jar file imported by the extension use a label like this:
# `@maven_deps//gitiles-servlet/jar`.
maven_jar = module_extension(
  implementation = _maven_jar_impl,
  tag_classes = {
    "install": tag_class(attrs = {
        "name": attr.string(mandatory = True),
        "artifact": attr.string(mandatory = True),
        "attach_source": attr.bool(default = True),
        "exclude": attr.string_list(),
        "repository": attr.string(default = MAVEN_CENTRAL),
        "sha1": attr.string(mandatory = False),
        "src_sha1": attr.string(),
        "exports": attr.string_list(),
        "deps": attr.string_list(),
    })
  }
)
