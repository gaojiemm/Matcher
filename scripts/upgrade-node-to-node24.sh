#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
SCRIPT_REL_PATH="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_REL_PATH" == "$ROOT_DIR/"* ]]; then
  SCRIPT_REL_PATH="${SCRIPT_REL_PATH#"$ROOT_DIR"/}"
else
  SCRIPT_REL_PATH="${SCRIPT_REL_PATH#./}"
fi
NODE20_MATCH_PATTERN=$(
  cat <<'PATTERN'
node20|Node20|node[-_ ]20|Node[-_ ]20|node:20|node-version[[:space:]]*:[[:space:]]*["']?20(\.x)?["']?|NODE_VERSION[[:space:]]*[:=][[:space:]]*["']?20(\.x)?["']?
PATTERN
)
NODE20_REPLACE_SCRIPT=$(
  cat <<'PERL'
    s/\bnode20\b/node24/g;
    s/\bNode20\b/Node24/g;
    s/\bnode([-_ ])20\b/node$124/g;
    s/\bNode([-_ ])20\b/Node$124/g;
    s/\bnode:20(?=\b|[.:-])/node:24/g;
    s/(\bnode-version\s*:\s*["\x27]?)20(?:\.x)?(["\x27]?)/${1}24$2/g;
    s/(\bNODE_VERSION\s*[:=]\s*["\x27]?)20(?:\.x)?(["\x27]?)/${1}24$2/g;
PERL
)

changed_files=()

while IFS= read -r file; do
  if [[ ! -f "$file" ]]; then
    continue
  fi

  case "$file" in
    "$SCRIPT_REL_PATH"|".github/workflows/upgrade-node-to-node24.yml")
      continue
      ;;
  esac

  if ! grep -Iq . "$file"; then
    continue
  fi

  if ! grep -Eq "$NODE20_MATCH_PATTERN" "$file"; then
    continue
  fi

  before_hash="$(sha256sum "$file" | awk '{print $1}')"

  perl -0pi -e "$NODE20_REPLACE_SCRIPT" "$file"

  after_hash="$(sha256sum "$file" | awk '{print $1}')"
  if [[ "$before_hash" != "$after_hash" ]]; then
    changed_files+=("$file")
  fi
done < <(git ls-files)

if [[ ${#changed_files[@]} -eq 0 ]]; then
  echo "No Node 20 references were updated."
  exit 0
fi

echo "Updated files (${#changed_files[@]}):"
for file in "${changed_files[@]}"; do
  echo "- $file"
done
