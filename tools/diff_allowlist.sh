#!/usr/bin/env bash
set -euo pipefail

ALLOWLIST="${1:?missing allowlist file}"
GENERATED="${2:?missing generated manifest file}"
HINT="${3:-}"

if [[ ! -f "${ALLOWLIST}" ]]; then
  echo "" >&2
  echo "FAIL: Missing allowlist:" >&2
  echo "  ${ALLOWLIST}" >&2
  echo "" >&2
  if [[ -n "${HINT}" ]]; then
    echo "To refresh it:" >&2
    echo "  bazelisk build ${HINT}" >&2
    echo "  cp bazel-bin/$(basename "${GENERATED}") ${ALLOWLIST}" >&2
  else
    echo "To refresh it: build the corresponding manifest target and copy its output to the allowlist." >&2
  fi
  echo "" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

grep -vE '^\s*(#|$)' "${ALLOWLIST}" | sort -u > "${tmpdir}/allowlist.norm"
grep -vE '^\s*$' "${GENERATED}" | sort -u > "${tmpdir}/generated.norm"

if ! diff -u "${tmpdir}/allowlist.norm" "${tmpdir}/generated.norm" >&2; then
  echo "" >&2
  echo "FAIL: Packaged third-party JAR set changed." >&2
  echo "" >&2
  if [[ -n "${HINT}" ]]; then
    echo "If expected, refresh the allowlist with:" >&2
    echo "  bazelisk build ${HINT}" >&2
    echo "  cp bazel-bin/$(basename "${GENERATED}") ${ALLOWLIST}" >&2
  else
    echo "If expected, refresh the allowlist by rebuilding the manifest and copying it over." >&2
  fi
  echo "" >&2
  exit 1
fi

