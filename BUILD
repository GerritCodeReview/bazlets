load("@rules_java//java:defs.bzl", "java_library")
load("@bazlets_npm//:defs.bzl", "npm_link_all_packages")

npm_link_all_packages(name = "node_modules")

java_library(
    name = "gerrit-api-neverlink",
    neverlink = 1,
    exports = ["@maven//:com_google_gerrit_gerrit_plugin_api"],
)
