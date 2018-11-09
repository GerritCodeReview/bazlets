load("//tools:maven_jar.bzl", "maven_jar")

"""Bazel rule for fetching [Bouncycastle](https://www.bouncycastle.org/)
dependency
"""

# This should be the same version used in Gerrit.
BC_VERS = "1.60"

def bouncycastle_repos():
    maven_jar(
        name = "bouncycastle_bcprov",
        artifact = "org.bouncycastle:bcprov-jdk15on:" + BC_VERS,
        sha1 = "bd47ad3bd14b8e82595c7adaa143501e60842a84",
    )
    maven_jar(
        name = "bouncycastle_bcpg",
        artifact = "org.bouncycastle:bcpg-jdk15on:" + BC_VERS,
        sha1 = "13c7a199c484127daad298996e95818478431a2c",
    )
    maven_jar(
        name = "bouncycastle_bcpkix",
        artifact = "org.bouncycastle:bcpkix-jdk15on:" + BC_VERS,
        sha1 = "d0c46320fbc07be3a24eb13a56cee4e3d38e0c75",
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
