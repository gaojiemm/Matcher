#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

actions=(
  "common/create-pipeline-context"
  "common/decide-env"
  "common/js-action-template"
)

for action_dir in "${actions[@]}"; do
  echo "== building ${action_dir} =="
  (
    cd "$repo_root/$action_dir"
    npm ci
    npm run package
  )
done

echo "All common actions packaged successfully."