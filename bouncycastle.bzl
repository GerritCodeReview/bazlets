load("//tools:maven_jar.bzl", "maven_jar")

"""Bazel rule for fetching [Bouncycastle](https://www.bouncycastle.org/)
dependency
"""

# This should be the same version used in Gerrit.
BC_VERS = "1.57"

def bouncycastle_repos():
    maven_jar(
        name = "bouncycastle_bcprov",
        artifact = "org.bouncycastle:bcprov-jdk15on:" + BC_VERS,
        sha1 = "f66a135611d42c992e5745788c3f94eb06464537",
    )
    maven_jar(
        name = "bouncycastle_bcpg",
        artifact = "org.bouncycastle:bcpg-jdk15on:" + BC_VERS,
        sha1 = "7b2d587f5e3780b79e1d35af3e84d00634e9420b",
    )
    maven_jar(
        name = "bouncycastle_bcpkix",
        artifact = "org.bouncycastle:bcpkix-jdk15on:" + BC_VERS,
        sha1 = "5c96e34bc9bd4cd6870e6d193a99438f1e274ca7",
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
