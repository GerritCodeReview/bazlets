IN_TREE_BUILD_MODE = False

PLUGIN_DEPS_NEVERLINK = [
    "//external:gerrit-plugin-api-neverlink",
]

PLUGIN_DEPS = [
    "//external:gerrit-plugin-api",
]

PLUGIN_TEST_DEPS = [
    "//external:bcpg",
    "//external:bcpkix",
    "//external:bcprov",
    "//external:gerrit-acceptance-framework",
]
