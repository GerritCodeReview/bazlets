load("@rules_python//python:defs.bzl", "py_binary", "py_test")

package(
    default_visibility = ["//visibility:public"],
)

py_binary(
    name = "project",
    srcs = ["project.py"],
    main = "project.py",
)

py_test(
    name = "test_project",
    srcs = ["test_project.py"],
    deps = [":project"],
)

test_suite(
    name = "test",
    tests = [
        "test_project",
    ]
)
