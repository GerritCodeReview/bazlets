load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

def gerrit_polymer():
    http_archive(
        name = "io_bazel_rules_closure",
        sha256 = "bdb00831682cd0923df36e19b01619b8230896d582f16304a937d8dc8270b1b6",
        strip_prefix = "rules_closure-ad75d7cc1cff0e845cd83683881915d995bd75b2",
        urls = ["https://github.com/bazelbuild/rules_closure/archive/ad75d7cc1cff0e845cd83683881915d995bd75b2.tar.gz"],
    )

    # File is specific to Polymer and copied from the Closure Github -- should be
    # synced any time there are major changes to Polymer.
    # https://github.com/google/closure-compiler/blob/master/contrib/externs/polymer-1.0.js
    http_file(
        name = "polymer_closure",
        sha256 = "5a589bdba674e1fec7188e9251c8624ebf2d4d969beb6635f9148f420d1e08b1",
        urls = ["https://raw.githubusercontent.com/google/closure-compiler/775609aad61e14aef289ebec4bfc09ad88877f9e/contrib/externs/polymer-1.0.js"],
    )
