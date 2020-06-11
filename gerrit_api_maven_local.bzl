load("//:gerrit_api.bzl", "gerrit_api")

"""Deprecated. This is only kept around for compatibility. Please use
`gerrit_api` directly and set the parameter `local` to `True`"""

def gerrit_api_maven_local():
    gerrit_api(local=True)
