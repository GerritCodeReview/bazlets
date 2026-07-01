# Copyright (C) 2026 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Servlet-flavour source transform.
#
# Generates a srcjar from canonical Java sources by rewriting the servlet (and
# Jetty EE) package prefixes, preserving Java package names and source line
# numbers (debugger breakpoints line up). The servlet/Jetty package mapping is
# universal and lives here once; a consumer selects only the direction:
#
#   to_javax    jakarta.servlet -> javax.servlet, Jetty ee11 -> ee8
#               (JGit's .ee8 bridge: jakarta-canonical -> javax consumers)
#   to_jakarta  javax.servlet -> jakarta.servlet, Jetty ee8 -> ee11
#               (Gitiles' .ee11 bridge: javax-canonical -> jakarta consumers)
#
# The rewrite is a plain `sed` package-prefix substitution, so it needs no
# external dependency and is self-contained. Consumers carry no renames data.

# Ordered (more specific prefix first) so a longer rename wins before its prefix.
_RENAMES = {
    "to_javax": [
        ("jakarta.servlet", "javax.servlet"),
        # SessionHandler moved from ee8.nested to ee11.servlet. Must precede the
        # broad ee11.servlet -> ee8.servlet rule below (otherwise it would become
        # ee8.servlet.SessionHandler). Other ee8.nested types (Request, Response,
        # ErrorHandler) map to core, not ee11.servlet, so only SessionHandler
        # gets a rule.
        ("org.eclipse.jetty.ee11.servlet.SessionHandler", "org.eclipse.jetty.ee8.nested.SessionHandler"),
        ("org.eclipse.jetty.ee11.servlet.security", "org.eclipse.jetty.ee8.security"),
        ("org.eclipse.jetty.ee11.servlet", "org.eclipse.jetty.ee8.servlet"),
    ],
    "to_jakarta": [
        ("javax.servlet", "jakarta.servlet"),
        ("org.eclipse.jetty.ee8.nested.SessionHandler", "org.eclipse.jetty.ee11.servlet.SessionHandler"),
        ("org.eclipse.jetty.ee8.security", "org.eclipse.jetty.ee11.servlet.security"),
        ("org.eclipse.jetty.ee8.servlet", "org.eclipse.jetty.ee11.servlet"),
    ],
}

def _transform_srcjar_impl(ctx):
    output_srcjar = ctx.actions.declare_file(ctx.label.name + ".srcjar")
    src_prefix = ctx.attr.src_prefix

    # Escape regex-significant dots in the source prefix; sed replacement text
    # takes dots literally.
    sed_lines = [
        "s/%s/%s/g" % (src_pkg.replace(".", "\\."), dst_pkg)
        for src_pkg, dst_pkg in _RENAMES[ctx.attr.direction]
    ]
    sed_script = ctx.actions.declare_file(ctx.label.name + ".sed")
    ctx.actions.write(output = sed_script, content = "\n".join(sed_lines) + "\n")

    args = ctx.actions.args()
    args.add(output_srcjar)
    args.add(src_prefix)
    args.add(sed_script)
    args.add_all(ctx.files.sources)

    ctx.actions.run_shell(
        inputs = ctx.files.sources + [sed_script],
        outputs = [output_srcjar],
        arguments = [args],
        command = """
set -euo pipefail

out="$1"
src_prefix="$2"
sed_script="$3"
shift 3
out="${PWD}/${out}"

work="$(mktemp -d "${TMPDIR:-/tmp}/servlet-transform.XXXXXX")"
trap 'rm -rf "${work}"' EXIT

for src in "$@"; do
  case "${src}" in
    *"${src_prefix}"*)
      internal="${src#*"${src_prefix}"}"
      ;;
    *)
      echo "Source ${src} does not contain ${src_prefix}" >&2
      exit 1
      ;;
  esac
  mkdir -p "${work}/$(dirname "${internal}")"
  sed -f "${sed_script}" "${src}" > "${work}/${internal}"
done

cd "${work}"
find . -type f -exec touch -t 200001010000.00 {} +
LC_ALL=C find . -type f | sort | zip -qDX@ "${out}"
""",
        mnemonic = "TransformServletSrcJar",
        progress_message = "Rewriting servlet imports for %s" % ctx.label,
    )

    return [DefaultInfo(files = depset([output_srcjar]))]

transform_srcjar = rule(
    implementation = _transform_srcjar_impl,
    doc = "Rewrite servlet package prefixes (per direction) into a srcjar.",
    attrs = {
        "direction": attr.string(
            mandatory = True,
            values = ["to_javax", "to_jakarta"],
            doc = "Rewrite direction; the package mapping is built in.",
        ),
        "sources": attr.label_list(
            allow_files = [".java"],
            mandatory = True,
            doc = "Canonical Java sources to rewrite.",
        ),
        "src_prefix": attr.string(
            mandatory = True,
            doc = "Path prefix stripped from each source to form its srcjar entry.",
        ),
    },
)
