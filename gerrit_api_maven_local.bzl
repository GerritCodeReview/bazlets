load("//:gerrit_api.bzl", "gerrit_api", "VER")

"""Deprecated. This is only kept around for compatibility. Please use
`gerrit_api` directly and set the parameter `local` to `True`"""

def gerrit_api_maven_local():
    # We append "-SNAPSHOT" if needed, to make sure the jars get
    # picked from the local Maven repository.
    version = VER if VER.endswith("-SNAPSHOT") else (VER + "-SNAPSHOT")
    gerrit_api(version = version)
