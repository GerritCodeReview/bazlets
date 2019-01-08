load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

def gerrit_polymer():
    http_archive(
        name = "io_bazel_rules_closure",
        sha256 = "d797d2410358bc8a4ceb1d26319b899acf4201f39cf2a99eb4b57212c01d76c7",
        strip_prefix = "rules_closure-a34455e0c76769df13d25b67851252559fe7f83d",
        urls = ["https://github.com/bazelbuild/rules_closure/archive/a34455e0c76769df13d25b67851252559fe7f83d.tar.gz"],
    )

    # File is specific to Polymer and copied from the Closure Github -- should be
    # synced any time there are major changes to Polymer.
    # https://github.com/google/closure-compiler/blob/master/contrib/externs/polymer-1.0.js
    http_file(
        name = "polymer_closure",
        sha256 = "5a589bdba674e1fec7188e9251c8624ebf2d4d969beb6635f9148f420d1e08b1",
        urls = ["https://raw.githubusercontent.com/google/closure-compiler/775609aad61e14aef289ebec4bfc09ad88877f9e/contrib/externs/polymer-1.0.js"],
    )
