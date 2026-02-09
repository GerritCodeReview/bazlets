load("//tools:maven_jar.bzl", "maven_jar")

"""Bazel rule for fetching [Bouncycastle](https://www.bouncycastle.org/)
dependency
"""

# This should be the same version used in Gerrit.
BC_VERS = "1.83"

def bouncycastle_repos():
    maven_jar(
        name = "bouncycastle_bcprov",
        artifact = "org.bouncycastle:bcprov-jdk18on:" + BC_VERS,
        sha1 = "310e719f391bd9f4ee5103ca299c172643efb595",
    )
    maven_jar(
        name = "bouncycastle_bcpg",
        artifact = "org.bouncycastle:bcpg-jdk18on:" + BC_VERS,
        sha1 = "4369727b9b02e6c62c26fde862ac42d77ce8edef",
    )
    maven_jar(
        name = "bouncycastle_bcpkix",
        artifact = "org.bouncycastle:bcpkix-jdk18on:" + BC_VERS,
        sha1 = "3f4300d0441459bfa64a481c80062b002ff0cf65",
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
