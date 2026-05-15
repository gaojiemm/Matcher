#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <node-major-version>" >&2
  exit 1
fi

expected_major="$1"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! "$expected_major" =~ ^[0-9]+$ ]]; then
  echo "node major version must be numeric: $expected_major" >&2
  exit 1
fi

expected_runtime="node${expected_major}"
expected_engine=">=${expected_major}"
workflow_file="$repo_root/.github/workflows/node24-action-demo.yml"

check_action_manifest() {
  local file_path="$1"
  if ! grep -Eq "^[[:space:]]+using:[[:space:]]+${expected_runtime}$" "$file_path"; then
    echo "runtime mismatch in $file_path: expected runs.using: ${expected_runtime}" >&2
    exit 1
  fi
}

check_package_json() {
  local file_path="$1"
  if ! grep -Eq "\"node\"[[:space:]]*:[[:space:]]*\"${expected_engine}\"" "$file_path"; then
    echo "engine mismatch in $file_path: expected \"node\": \"${expected_engine}\"" >&2
    exit 1
  fi
}

check_workflow() {
  if [[ ! -f "$workflow_file" ]]; then
    echo "workflow file not found: $workflow_file" >&2
    exit 1
  fi

  if ! grep -Eq "^[[:space:]]+node-version:[[:space:]]+${expected_major}$" "$workflow_file"; then
    echo "workflow mismatch in $workflow_file: expected node-version: ${expected_major}" >&2
    exit 1
  fi
}

while IFS= read -r action_file; do
  check_action_manifest "$action_file"
done < <(find "$repo_root/common" -mindepth 2 -maxdepth 2 -name action.yml | sort)

while IFS= read -r package_file; do
  check_package_json "$package_file"
done < <(find "$repo_root/common" -mindepth 2 -maxdepth 2 -name package.json | sort)

check_workflow

echo "All action runtime declarations match Node ${expected_major}."