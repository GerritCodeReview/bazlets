#!/usr/bin/env bash
set -euo pipefail

LEFT="${1:?missing left list}"
RIGHT="${2:?missing right list}"
# Bazel sh_test args are not guaranteed to preserve spaces as a single argv element
# across all wrappers/platforms. The hint is free-form text, so treat it as "all
# remaining args" (argv[3..]) to avoid truncating it to the first word.
HINT="${*:3}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

# Normalize: drop comments/blank lines, sort unique
grep -vE '^\s*(#|$)' "${LEFT}"  | sort -u > "${tmpdir}/left.norm"
grep -vE '^\s*(#|$)' "${RIGHT}" | sort -u > "${tmpdir}/right.norm"

# Intersection (overlap)
comm -12 "${tmpdir}/left.norm" "${tmpdir}/right.norm" > "${tmpdir}/overlap"

if [[ -s "${tmpdir}/overlap" ]]; then
  echo "" >&2
  echo "FAIL: Plugin bundles third-party JARs that are also provided by Gerrit:" >&2
  cat "${tmpdir}/overlap" >&2
  echo "" >&2
  echo "Exclude these artifacts from the plugin to avoid duplicate classes and version skew at runtime." >&2
  echo "" >&2

  if [[ -n "${HINT}" ]]; then
    echo "Fix:" >&2
    echo "  ${HINT}" >&2
  else
    echo "Fix:" >&2
    echo "  Exclude the overlapping artifacts from maven.install(excluded_artifacts = [...])" >&2
    echo "  (or treat them as provided_deps if they come from Gerrit)." >&2
  fi

  echo "" >&2
  exit 1
fi
