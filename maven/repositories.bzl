load("//maven/private:maven_jar.bzl", _maven_jar="maven_jar")

# To install a single maven_jar, add the following to a BUILD file:
#
#   ```
#   load("@com_googlesource_gerrit_bazlets//maven:repositories.bzl", "maven_jar")
#
#   maven_jar(
#       name = "log-api",
#       artifact = "org.slf4j:slf4j-api:" + SLF4J_VERS,
#       sha1 = "6c62681a2f655b49963a5983b8b0950a6120ae14",
#   )
#   ```
#
# This will create a repository for each maven_jar rule, that can be referenced
# by using the label `@<rule name>//jar` to retrieve the JAR file.
maven_jar = _maven_jar
