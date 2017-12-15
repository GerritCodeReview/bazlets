load("//tools:maven_jar.bzl", "maven_jar")

PROLOG_VERS = "1.4.3"

PROLOG_REPO = GERRIT

maven_jar(
    name = "prolog_runtime",
    artifact = "com.googlecode.prolog-cafe:prolog-runtime:" + PROLOG_VERS,
    attach_source = False,
    repository = PROLOG_REPO,
    sha1 = "d5206556cbc76ffeab21313ffc47b586a1efbcbb",
)

maven_jar(
    name = "prolog_compiler",
    artifact = "com.googlecode.prolog-cafe:prolog-compiler:" + PROLOG_VERS,
    attach_source = False,
    repository = PROLOG_REPO,
    sha1 = "f37032cf1dec3e064427745bc59da5a12757a3b2",
)

maven_jar(
    name = "prolog_io",
    artifact = "com.googlecode.prolog-cafe:prolog-io:" + PROLOG_VERS,
    attach_source = False,
    repository = PROLOG_REPO,
    sha1 = "d02b2640b26f64036b6ba2b45e4acc79281cea17",
)

maven_jar(
    name = "cafeteria",
    artifact = "com.googlecode.prolog-cafe:prolog-cafeteria:" + PROLOG_VERS,
    attach_source = False,
    repository = PROLOG_REPO,
    sha1 = "e3b1860c63e57265e5435f890263ad82dafa724f",
)

native.bind(
  name = "prolog_runtime",
  actual = "@prolog_runtime//jar"
)

native.bind(
  name = "prolog_runtime",
  actual = "@prolog_runtime//jar"
)

native.bind(
  name = "prolog_runtime",
  actual = "@prolog_runtime//jar"
)

native.bind(
  name = "prolog_runtime",
  actual = "@prolog_runtime//jar"
)
