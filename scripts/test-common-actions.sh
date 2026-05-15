#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required but was not found in PATH" >&2
  exit 1
fi

run_action() {
  local action_dir="$1"
  shift
  (
    cd "$repo_root/$action_dir"
    "$@"
  )
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected output to contain: $needle" >&2
    exit 1
  fi
}

test_create_pipeline_context() {
  local output_file
  output_file="$(mktemp)"
  echo "== create-pipeline-context success =="
  run_action common/create-pipeline-context env \
    INPUT_SERVICE=matcher-demo \
    INPUT_TEST_PARALLEL_KEYS='["unit-1","unit-2"]' \
    GITHUB_OUTPUT="$output_file" \
    node dist/index.js
  local output
  output="$(cat "$output_file")"
  assert_contains "$output" '"service":"matcher-demo","runtime":"node24"'
  assert_contains "$output" '["unit-1","unit-2"]'
  printf '%s\n' "$output"
  rm -f "$output_file"
}

test_decide_env() {
  local output_file
  output_file="$(mktemp)"
  echo "== decide-env success =="
  run_action common/decide-env env \
    INPUT_BRANCH_NAME=release/2026.05 \
    GITHUB_OUTPUT="$output_file" \
    node dist/index.js
  local output
  output="$(cat "$output_file")"
  assert_contains "$output" 'staging'
  assert_contains "$output" 'true'
  printf '%s\n' "$output"
  rm -f "$output_file"
}

test_js_action_template() {
  local output_file
  output_file="$(mktemp)"
  echo "== js-action-template success =="
  run_action common/js-action-template env \
    INPUT_NAME=matcher-demo \
    INPUT_PAYLOAD='{"feature":"node24"}' \
    GITHUB_OUTPUT="$output_file" \
    node dist/index.js
  local output
  output="$(cat "$output_file")"
  assert_contains "$output" 'Hello, matcher-demo from Node 24.'
  assert_contains "$output" '{"feature":"node24"}'
  printf '%s\n' "$output"
  rm -f "$output_file"
}

test_create_pipeline_context
test_decide_env
test_js_action_template

echo "All common Node 24 action tests passed."