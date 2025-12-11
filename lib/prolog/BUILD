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
        "@maven//:com_googlecode_prolog_cafe_prolog_compiler",
        "@maven//:com_googlecode_prolog_cafe_prolog_io",
        "@maven//:com_googlecode_prolog_cafe_prolog_runtime",
    ],
)
