#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "usage: $0 <target-node-major> [--skip-validate]" >&2
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

target_major="$1"
skip_validate="false"

if [[ $# -eq 2 ]]; then
  if [[ "$2" != "--skip-validate" ]]; then
    usage
  fi
  skip_validate="true"
fi

if [[ ! "$target_major" =~ ^[0-9]+$ ]]; then
  echo "target node major version must be numeric: $target_major" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node is required but was not found in PATH" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
current_major="$(node -p "process.versions.node.split('.')[0]")"

if [[ "$skip_validate" != "true" && "$current_major" != "$target_major" ]]; then
  echo "current node major is $current_major but target is $target_major" >&2
  echo "switch to Node $target_major first, or rerun with --skip-validate to update declarations only" >&2
  exit 1
fi

node - <<'NODE' "$repo_root" "$target_major"
const fs = require('fs');
const path = require('path');

const repoRoot = process.argv[2];
const targetMajor = process.argv[3];
const targetRuntime = `node${targetMajor}`;
const targetEngine = `>=${targetMajor}`;

const actionDirs = [
  'common/create-pipeline-context',
  'common/decide-env',
  'common/js-action-template',
];

const textFiles = [
  '.github/workflows/node24-action-demo.yml',
  'README.md',
  'NODE24_EXPLANATION.md',
  'scripts/verify-action-runtime.sh',
];

for (const actionDir of actionDirs) {
  const actionFile = path.join(repoRoot, actionDir, 'action.yml');
  const actionText = fs.readFileSync(actionFile, 'utf8').replace(/using:\s*node\d+/g, `using: ${targetRuntime}`);
  fs.writeFileSync(actionFile, actionText);

  for (const jsonName of ['package.json', 'package-lock.json']) {
    const jsonPath = path.join(repoRoot, actionDir, jsonName);
    const parsed = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

    if (parsed.engines && parsed.engines.node) {
      parsed.engines.node = targetEngine;
    }

    if (parsed.packages && parsed.packages[''] && parsed.packages[''].engines && parsed.packages[''].engines.node) {
      parsed.packages[''].engines.node = targetEngine;
    }

    fs.writeFileSync(jsonPath, `${JSON.stringify(parsed, null, 2)}\n`);
  }
}

for (const relativePath of textFiles) {
  const filePath = path.join(repoRoot, relativePath);
  let text = fs.readFileSync(filePath, 'utf8');
  text = text.replace(/node-version:\s*\d+/g, `node-version: ${targetMajor}`);
  text = text.replace(/Node\s+\d+\s+Action\s+Demo/g, `Node ${targetMajor} Action Demo`);
  text = text.replace(/verify-action-runtime\.sh\s+\d+/g, `verify-action-runtime.sh ${targetMajor}`);
  text = text.replace(/runs\.using:?\s*`?node\d+`?/g, (match) => match.replace(/node\d+/, targetRuntime));
  text = text.replace(/"node":\s*">=\d+"/g, `"node": ">=${targetMajor}"`);
  text = text.replace(/node24/g, targetRuntime);
  text = text.replace(/Node\s+24/g, `Node ${targetMajor}`);
  text = text.replace(/>=24/g, targetEngine);
  fs.writeFileSync(filePath, text);
}
NODE

echo "Updated runtime declarations to Node $target_major."

if [[ "$skip_validate" == "true" ]]; then
  echo "Skipped validation. Run build and test scripts manually on Node $target_major."
  exit 0
fi

bash "$repo_root/scripts/verify-action-runtime.sh" "$target_major"
bash "$repo_root/scripts/build-common-actions.sh"
bash "$repo_root/scripts/test-node24-action.sh"
bash "$repo_root/scripts/test-common-actions.sh"

echo "Node $target_major upgrade completed and validations passed."