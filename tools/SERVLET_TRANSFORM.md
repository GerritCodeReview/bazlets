# Servlet-flavour transform toolchain

Shared Bazel machinery for generating a second servlet-API flavour of a Java
module from one canonical source tree, by rewriting only the servlet (and Jetty
EE) package prefixes while preserving Java package names and source line numbers.

It is **self-contained**: the rewrite is a plain `sed` package-prefix
substitution, so it pulls in **no external dependency**.

## The package mapping lives here, once

The servlet/Jetty package mapping is universal, so it is baked into the rule.
Consumers carry **no** renames data — they select only the direction:

| `direction` | Rewrites | Used by |
|---|---|---|
| `to_javax` | jakarta.servlet -> javax.servlet, Jetty ee10 -> ee8 | JGit `.ee8` bridge (jakarta-canonical) |
| `to_jakarta` | javax.servlet -> jakarta.servlet, Jetty ee8 servlet/security -> ee10 servlet/security | Gitiles `.ee10` bridge (javax-canonical) |

If a consumer ever needs a rename outside this universal set, add an optional
`extra_renames` attribute (or reference a `.properties` hosted here) — not needed
today.

## Contents

* `servlet_transform.bzl` — `transform_srcjar(name, sources, src_prefix, direction)`
  rule producing a srcjar with the renames applied.
* Generated test targets reuse the canonical `junit_tests` macro from
  `junit.bzl` via its optional `suite_srcs` parameter: pass the transformed test
  `.srcjar` as `srcs` (compiled) and the canonical `.java` test files as
  `suite_srcs` (scanned for the `@Suite.SuiteClasses` names). This works because
  the transform preserves package and class names, so the canonical files yield
  exactly the classes inside the srcjar — no separate junit macro is needed.
* `generated_srcs_test.sh` — derivation / line-count / residue checker. The
  residue checks are caller-supplied (`--forbid`, `--require`,
  `--require-if-source`) so it works in either direction.

## Usage

```python
load("@com_googlesource_gerrit_bazlets//tools:servlet_transform.bzl", "transform_srcjar")
load("@com_googlesource_gerrit_bazlets//tools:junit.bzl", "junit_tests")

# Generate the flavour srcjar.
transform_srcjar(
    name = "jgit-servlet-ee8-srcs",
    direction = "to_javax",
    sources = ["//org.eclipse.jgit.http.server:srcs"],
    src_prefix = "org.eclipse.jgit.http.server/src/",
)

# Run the generated tests: compile the transformed srcjar, but derive the
# suite class names from the canonical test files via suite_srcs.
junit_tests(
    name = "http",
    srcs = [":http-test-ee8-srcs"],  # transformed test srcjar (compiled)
    suite_srcs = ["//org.eclipse.jgit.http.test:test-srcs"],  # canonical .java
    deps = ["..."],
)

sh_test(
    name = "generated_srcs_test",
    srcs = ["@com_googlesource_gerrit_bazlets//tools:generated_srcs_test.sh"],
    args = [
        "--forbid", "jakarta\\.servlet",
        "--require", "javax\\.servlet",
        "--module", "org.eclipse.jgit.http.server/src/",
        "$(location :jgit-servlet-ee8-srcs)",
        "$(locations //org.eclipse.jgit.http.server:srcs)",
    ],
    data = [":jgit-servlet-ee8-srcs", "//org.eclipse.jgit.http.server:srcs"],
)
```

Each repo keeps only its own test target wiring; no renames data is duplicated.
