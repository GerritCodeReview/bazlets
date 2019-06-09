load("//tools:maven_jar.bzl", "maven_jar")

"""Bazel rule for fetching [Bouncycastle](https://www.bouncycastle.org/)
dependency
"""

# This should be the same version used in Gerrit.
BC_VERS = "1.61"

def bouncycastle_repos():
    maven_jar(
        name = "bouncycastle_bcprov",
        artifact = "org.bouncycastle:bcprov-jdk15on:" + BC_VERS,
        sha1 = "00df4b474e71be02c1349c3292d98886f888d1f7",
    )
    maven_jar(
        name = "bouncycastle_bcpg",
        artifact = "org.bouncycastle:bcpg-jdk15on:" + BC_VERS,
        sha1 = "422656435514ab8a28752b117d5d2646660a0ace",
    )
    maven_jar(
        name = "bouncycastle_bcpkix",
        artifact = "org.bouncycastle:bcpkix-jdk15on:" + BC_VERS,
        sha1 = "89bb3aa5b98b48e584eee2a7401b7682a46779b4",
    )
    native.bind(
        name = "bcprov",
        actual = "@bouncycastle_bcprov//jar",
    )
    native.bind(
        name = "bcprov-neverlink",
        actual = "@bouncycastle_bcprov//jar:neverlink",
    )
    native.bind(
        name = "bcpg",
        actual = "@bouncycastle_bcpg//jar",
    )
    native.bind(
        name = "bcpg-neverlink",
        actual = "@bouncycastle_bcpg//jar:neverlink",
    )
    native.bind(
        name = "bcpkix",
        actual = "@bouncycastle_bcpkix//jar",
    )
    native.bind(
        name = "bcpkix-neverlink",
        actual = "@bouncycastle_bcpkix//jar:neverlink",
    )
