load("@rules_python//python:defs.bzl", "py_binary", "py_library")

exports_files([
    "diff_allowlist.sh",
    "diff_overlap.sh",
    "generated_srcs_test.sh",
    "java_runtime_jars_manifest.bzl",
    "runtime_jars_allowlist.bzl",
    "runtime_jars_overlap.bzl",
    "sbom.bzl",
    "sbom_scan.bzl",
    "trivy_scan.sh",
])

py_library(
    name = "sbom_from_graph_lib",
    srcs = ["sbom_from_graph.py"],
    imports = ["."],
)

py_binary(
    name = "sbom_from_graph",
    srcs = ["sbom_from_graph.py"],
    main = "sbom_from_graph.py",
    visibility = ["//visibility:public"],
    deps = [":sbom_from_graph_lib"],
)
