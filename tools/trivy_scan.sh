#!/usr/bin/env bash
#
# Scan a CycloneDX SBOM for known vulnerabilities with Trivy and fail on
# findings at the selected severities. Used by sbom_scan() for Gerrit,
# Gitiles and plugins.
#
# Usage: trivy_scan.sh <sbom.cyclonedx.json> [ignorefile]

set -euo pipefail

sbom="$1"
ignorefile="${2:-}"
severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"

if ! command -v trivy >/dev/null 2>&1; then
  echo "trivy is not on PATH." >&2
  echo "Install it (macOS: brew install trivy) or run inside the CI image." >&2
  exit 1
fi

args=(sbom "$sbom" --exit-code 1 --severity "$severity")
if [[ -n "$ignorefile" && -f "$ignorefile" ]]; then
  args+=(--ignorefile "$ignorefile")
fi

echo "+ trivy ${args[*]}"
exec trivy "${args[@]}"
