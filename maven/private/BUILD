load("@rules_python//python:python.bzl", "py_library")

py_library(
    name = "download_file",
    srcs = ["download_file.py", "util.py"],
)

export_files(
  glob(["*.bzl"]),
  visibility = ["//visibility:public"],
)
