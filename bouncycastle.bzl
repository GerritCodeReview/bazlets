load("//tools:maven_jar.bzl", "maven_jar")

"""Bazel rule for fetching [Bouncycastle](https://www.bouncycastle.org/)
dependency
"""

# This should be the same version used in Gerrit.
BC_VERS = "1.72"

def bouncycastle_repos():
    maven_jar(
        name = "bouncycastle_bcprov",
        artifact = "org.bouncycastle:bcprov-jdk18on:" + BC_VERS,
        sha1 = "d8dc62c28a3497d29c93fee3e71c00b27dff41b4",
    )
    maven_jar(
        name = "bouncycastle_bcpg",
        artifact = "org.bouncycastle:bcpg-jdk18on:" + BC_VERS,
        sha1 = "1a36a1740d07869161f6f0d01fae8d72dd1d8320",
    )
    maven_jar(
        name = "bouncycastle_bcpkix",
        artifact = "org.bouncycastle:bcpkix-jdk18on:" + BC_VERS,
        sha1 = "bb3fdb5162ccd5085e8d7e57fada4d8eaa571f5a",
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
