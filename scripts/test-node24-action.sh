#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
action_dir="$repo_root/common/create-pipeline-context"
action_script="$action_dir/dist/index.js"
expected_runtime="node$(node -p "process.versions.node.split('.')[0]")"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required but was not found in PATH" >&2
  exit 1
fi

if [[ ! -f "$action_script" ]]; then
  echo "action script not found: $action_script" >&2
  exit 1
fi

run_success_case() {
  local output_file
  output_file="$(mktemp)"

  echo "== success case =="
  (
    cd "$action_dir"
    export INPUT_SERVICE="matcher-demo"
    export INPUT_TEST_PARALLEL_KEYS='["unit-1","unit-2"]'
    export GITHUB_OUTPUT="$output_file"
    node dist/index.js
  )

  grep -F "\"service\":\"matcher-demo\",\"runtime\":\"$expected_runtime\"" "$output_file" >/dev/null
  grep -F '["unit-1","unit-2"]' "$output_file" >/dev/null
  cat "$output_file"
  rm -f "$output_file"
}

run_failure_case() {
  local title="$1"
  local expected_message="$2"
  shift 2

  echo "== $title =="

  set +e
  local output
  output="$(
    cd "$action_dir"
    env -i PATH="$PATH" HOME="$HOME" "$@" 2>&1
  )"
  local exit_code=$?
  set -e

  printf '%s\n' "$output"

  if [[ $exit_code -eq 0 ]]; then
    echo "expected failure but command succeeded" >&2
    exit 1
  fi

  if [[ "$output" != *"$expected_message"* ]]; then
    echo "expected error message not found: $expected_message" >&2
    exit 1
  fi
}

run_success_case
run_failure_case \
  "missing required input" \
  "Input required and not supplied: service" \
  node dist/index.js
run_failure_case \
  "invalid test-parallel-keys" \
  "Invalid test-parallel-keys" \
  INPUT_SERVICE=matcher-demo INPUT_TEST_PARALLEL_KEYS=not-json node dist/index.js

echo "All local action tests passed."