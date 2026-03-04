#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"
SPIKE_STALE_HOURS="${CARIS_SPIKE_STALE_HOURS:-48}"
FAIL_ON_STALE_SPIKES="${CARIS_FAIL_ON_STALE_SPIKES:-0}"

if ! command -v rg >/dev/null 2>&1; then
  echo "[ERROR] ripgrep (rg) is required for exclusion checks."
  exit 2
fi

if [ ! -d "$ROOT_DIR" ]; then
  echo "[ERROR] Root directory '$ROOT_DIR' was not found."
  exit 2
fi

BANNED_REGEX='legacy_api_folder|deprecated_utils'

mapfile -t matches < <(
  rg \
    --line-number \
    --with-filename \
    --color never \
    --glob '*.dart' \
    --glob '*.js' \
    --glob '*.jsx' \
    --glob '*.ts' \
    --glob '*.tsx' \
    --glob '*.py' \
    --glob '*.go' \
    --glob '*.rs' \
    --glob '*.java' \
    --glob '*.kt' \
    --glob '*.swift' \
    --glob '*.yml' \
    --glob '*.yaml' \
    --glob '!**/node_modules/**' \
    --glob '!**/.git/**' \
    --glob '!**/dist/**' \
    --glob '!**/build/**' \
    --glob '!**/.next/**' \
    --glob '!**/coverage/**' \
    --glob '!**/templates/guardrails/**' \
    --glob '!**/experimental/**' \
    --glob '!experimental/**' \
    --glob '!**/*.proto.*' \
    --glob '!**/*.md' \
    -e "$BANNED_REGEX" \
    "$ROOT_DIR" || true
)

get_mtime_epoch() {
  local file="$1"
  if stat -c %Y "$file" >/dev/null 2>&1; then
    stat -c %Y "$file"
  else
    stat -f %m "$file"
  fi
}

now_epoch="$(date +%s)"
stale_found=0
stale_lines=()

while IFS= read -r spike_file; do
  [ -z "$spike_file" ] && continue
  mtime_epoch="$(get_mtime_epoch "$spike_file")"
  age_hours="$(( (now_epoch - mtime_epoch) / 3600 ))"
  if [ "$age_hours" -lt "$SPIKE_STALE_HOURS" ]; then
    continue
  fi
  stale_found=1
  stale_lines+=("[WARN] ${spike_file#./} (age: ${age_hours}h)")
done < <(
  find "$ROOT_DIR" \
    \( -path '*/.git/*' -o -path '*/node_modules/*' -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.next/*' -o -path '*/coverage/*' -o -path '*/templates/guardrails/*' \) -prune -o \
    -type f \( -path '*/experimental/*' -o -name '*.proto.*' \) -print
)

if [ "${#matches[@]}" -gt 0 ]; then
  echo "[ERROR] Exclusion zone violation detected."
  echo "[ERROR] Remove deprecated imports/references before commit or merge."
  printf '%s\n' "${matches[@]}"
  if [ "$stale_found" -eq 1 ]; then
    echo "[WARN] Spike Protocol staleness detected (older than ${SPIKE_STALE_HOURS}h):"
    printf '%s\n' "${stale_lines[@]}"
  fi
  exit 1
fi

if [ "$stale_found" -eq 1 ]; then
  echo "[WARN] Spike Protocol staleness detected (older than ${SPIKE_STALE_HOURS}h)."
  echo "[WARN] Refactor or delete stale prototypes before they become shadow code."
  echo "[WARN] Suggested next step: extract core logic, write failing tests, migrate to production path, then delete spike."
  printf '%s\n' "${stale_lines[@]}"

  if [ "$FAIL_ON_STALE_SPIKES" = "1" ]; then
    echo "[ERROR] Stale Spike Protocol artifacts found and fail mode is enabled (CARIS_FAIL_ON_STALE_SPIKES=1)."
    exit 1
  fi
fi

echo "[OK] No exclusion zone violations detected."
if [ "$stale_found" -eq 0 ]; then
  echo "[OK] No stale Spike Protocol artifacts older than ${SPIKE_STALE_HOURS} hours detected."
fi
