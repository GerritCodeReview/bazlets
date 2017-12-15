java_binary(
    name = "compiler_bin",
    main_class = "BuckPrologCompiler",
    visibility = ["//visibility:public"],
    runtime_deps = [":compiler_lib"],
)

java_library(
    name = "compiler_lib",
    srcs = ["java/BuckPrologCompiler.java"],
    visibility = ["//visibility:public"],
    deps = [
        "@prolog_compiler//jar",
        "@prolog_runtime//jar",
        "@prolog_io//jar",
    ],
)
