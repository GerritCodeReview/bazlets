java_binary(
    name = "compiler_bin",
    main_class = "PrologCompiler",
    visibility = ["//visibility:public"],
    runtime_deps = [":compiler_lib"],
)

java_library(
    name = "compiler_lib",
    srcs = ["java/PrologCompiler.java"],
    visibility = ["//visibility:public"],
    deps = [
        "@prolog_compiler//jar",
        "@prolog_runtime//jar",
        "@prolog_io//jar",
    ],
)
