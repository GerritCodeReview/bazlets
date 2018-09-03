load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

def gerrit_polymer():
    native.http_archive(
        name = "io_bazel_rules_closure",
        sha256 = "4dd84dd2bdd6c9f56cb5a475d504ea31d199c34309e202e9379501d01c3067e5",
        strip_prefix = "rules_closure-3103a773820b59b76345f94c231cb213e0d404e2",
        urls = ["https://github.com/bazelbuild/rules_closure/archive/3103a773820b59b76345f94c231cb213e0d404e2.tar.gz"],
    )

    # File is specific to Polymer and copied from the Closure Github -- should be
    # synced any time there are major changes to Polymer.
    # https://github.com/google/closure-compiler/blob/master/contrib/externs/polymer-1.0.js
    native.http_file(
        name = "polymer_closure",
        sha256 = "5a589bdba674e1fec7188e9251c8624ebf2d4d969beb6635f9148f420d1e08b1",
        urls = ["https://raw.githubusercontent.com/google/closure-compiler/775609aad61e14aef289ebec4bfc09ad88877f9e/contrib/externs/polymer-1.0.js"],
    )
