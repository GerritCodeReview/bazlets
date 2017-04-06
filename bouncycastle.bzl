load("//tools:maven_jar.bzl", "maven_jar")

"""Bazel rule for fetching [Bouncycastle](https://www.bouncycastle.org/)
dependency
"""

BC_VERS = "1.56"

def bouncycastle_repository():

  maven_jar(
      name = "bcprov",
      artifact = "org.bouncycastle:bcprov-jdk15on:" + BC_VERS,
      sha1 = "a153c6f9744a3e9dd6feab5e210e1c9861362ec7",
   )

  maven_jar(
      name = "bcpg",
      artifact = "org.bouncycastle:bcpg-jdk15on:" + BC_VERS,
      sha1 = "9c3f2e7072c8cc1152079b5c25291a9f462631f1",
   )

  maven_jar(
      name = "bcpkix",
      artifact = "org.bouncycastle:bcpkix-jdk15on:" + BC_VERS,
      sha1 = "4648af70268b6fdb24674fb1fd7c1fcc73db1231",
   )
