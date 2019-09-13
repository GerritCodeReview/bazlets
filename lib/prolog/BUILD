load("@rules_java//java:defs.bzl", "java_binary", "java_library")

java_binary(
    name = "compiler-bin",
    main_class = "PrologCompiler",
    visibility = ["//visibility:public"],
    runtime_deps = [":compiler-lib"],
)

java_library(
    name = "compiler-lib",
    srcs = ["java/PrologCompiler.java"],
    visibility = ["//visibility:public"],
    deps = [
        "@prolog-compiler//jar",
        "@prolog-io//jar",
        "@prolog-runtime//jar",
    ],
)
