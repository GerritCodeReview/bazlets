#!/usr/bin/env bash
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
#
# Verifies that generated servlet-flavour srcjars are faithfully derived from
# their canonical sources: same source entries, preserved line counts (so
# debugger breakpoints line up), and direction-specific residue checks.
#
# Direction-agnostic. The residue checks are supplied by the caller, so the same
# script serves both bridges (jakarta->javax and javax->jakarta):
#
#   --forbid REGEX                 fail if REGEX appears in the generated output
#                                  (repeatable, applies to every module)
#   --require REGEX                fail if REGEX is absent from the generated
#                                  output (repeatable)
#   --require-if-source SRC OUT    if any canonical source matches SRC, the
#                                  generated output must match OUT (repeatable)
#   --module PREFIX SRCJAR SRC...  a generated module: strip PREFIX from each
#                                  SRC to form its srcjar entry (repeatable)

set -euo pipefail

forbid=()
require=()
require_if_source_src=()
require_if_source_out=()

check_module() {
  local src_prefix="$1"
  local srcjar="$2"
  shift 2

  local tmp
  tmp="$(mktemp -d "${TEST_TMPDIR:-/tmp}/generated-srcs.XXXXXX")"

  local expected="${tmp}/expected"
  local actual="${tmp}/actual"
  : > "${expected}"

  local source
  for source in "$@"; do
    local entry="${source#*"${src_prefix}"}"
    if [[ "${entry}" == "${source}" ]]; then
      echo "Could not strip ${src_prefix} from ${source}" >&2
      exit 1
    fi
    echo "${entry}" >> "${expected}"

    local source_lines generated_lines
    source_lines="$(wc -l < "${source}" | tr -d ' ')"
    generated_lines="$(unzip -p "${srcjar}" "${entry}" | wc -l | tr -d ' ')"
    if [[ "${source_lines}" != "${generated_lines}" ]]; then
      echo "Line count changed for ${entry}: ${source_lines} -> ${generated_lines}" >&2
      exit 1
    fi
  done

  zipinfo -1 "${srcjar}" | sort > "${actual}"
  sort "${expected}" -o "${expected}"
  if ! diff -u "${expected}" "${actual}"; then
    echo "Generated source jar entries do not match input source list" >&2
    exit 1
  fi

  local all_sources="${tmp}/all-sources"
  local all_original_sources="${tmp}/all-original-sources"
  unzip -p "${srcjar}" > "${all_sources}"
  cat "$@" > "${all_original_sources}"

  local pat
  for pat in "${forbid[@]+"${forbid[@]}"}"; do
    if grep -n "${pat}" "${all_sources}"; then
      echo "Found forbidden pattern '${pat}' in ${srcjar}" >&2
      exit 1
    fi
  done

  for pat in "${require[@]+"${require[@]}"}"; do
    if ! grep -q "${pat}" "${all_sources}"; then
      echo "Required pattern '${pat}' missing from ${srcjar}" >&2
      exit 1
    fi
  done

  local i
  for i in "${!require_if_source_src[@]}"; do
    local src_pat="${require_if_source_src[$i]}"
    local out_pat="${require_if_source_out[$i]}"
    if grep -q "${src_pat}" "${all_original_sources}" &&
        ! grep -q "${out_pat}" "${all_sources}"; then
      echo "Sources match '${src_pat}' but '${out_pat}' missing from ${srcjar}" >&2
      exit 1
    fi
  done

  rm -rf "${tmp}"
}

modules_seen=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --forbid)
      forbid+=("$2")
      shift 2
      ;;
    --require)
      require+=("$2")
      shift 2
      ;;
    --require-if-source)
      require_if_source_src+=("$2")
      require_if_source_out+=("$3")
      shift 3
      ;;
    --module)
      modules_seen=$((modules_seen + 1))
      shift
      src_prefix="$1"
      srcjar="$2"
      shift 2
      sources=()
      while [[ "$#" -gt 0 && "$1" != "--module" ]]; do
        sources+=("$1")
        shift
      done
      if [[ "${#sources[@]}" -eq 0 ]]; then
        echo "No sources passed for ${src_prefix}" >&2
        exit 1
      fi
      check_module "${src_prefix}" "${srcjar}" "${sources[@]}"
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${modules_seen}" -eq 0 ]]; then
  echo "No --module checks were executed" >&2
  exit 1
fi
