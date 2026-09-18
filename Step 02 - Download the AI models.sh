/bin/bash <<'DAN_STEP_02'
# STEP 02 - Downloads the seven AI models (about 121 GB). Can take several hours.
# Leave the Mac plugged in with the lid open. If it stops, paste this block again:
# it continues where it left off.
set -Eeuo pipefail
fail() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }
ROOT="$HOME/Library/Application Support/DanLocalAI"
[[ -f "$ROOT/environment.sh" ]] || fail "Run Step 01 first."
source "$ROOT/environment.sh"
command -v hf >/dev/null 2>&1 || fail "The download tool is missing. Run Step 01 again."
MODELS="$HOME/.omlx/models"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$MODELS" "$ROOT/logs"
exec > >(tee "$ROOT/logs/step02-$STAMP.log") 2>&1
/usr/bin/caffeinate -is -w "$$" >/dev/null 2>&1 &

# Native MLX builds sized for an M1 Max: 4-bit keeps the big models fast enough
# for agents (an 8-bit 27B manages only about 6 tokens a second on this chip).
FAILED=0
while IFS='|' read -r repo role; do
  [[ -n "$repo" ]] || continue
  name="${repo##*/}"
  printf '\n=== %s  (%s) ===\n' "$name" "$role"
  OK=0
  for attempt in 1 2 3; do
    if hf download "$repo" --local-dir "$MODELS/$name" </dev/null; then OK=1; break; fi
    echo "Download interrupted (attempt $attempt of 3). Retrying in 20 seconds..."
    sleep 20
  done
  if [[ "$OK" -eq 1 ]]; then
    echo "DONE: $name"
  else
    echo "NOT FINISHED: $name"
    FAILED=$((FAILED + 1))
  fi
done <<'MODEL_LIST'
Jundot/Qwen3.6-35B-A3B-oQ4e-mtp|everyday agent, fast - 22 GB
mlx-community/Qwen3.5-4B-MLX-8bit|quick small jobs - 5 GB
mlx-community/Qwen3.5-9B-MLX-4bit|general worker - 6 GB
mlx-community/gemma-4-12B-it-qat-4bit|second worker and writing - 11 GB
Jundot/Qwen3.8-27B-oQ4e-mtp|deep thinker - 17 GB
mlx-community/Devstral-Small-2-24B-Instruct-2512-4bit|code reviewer - 15 GB
lmstudio-community/Qwen3-Coder-Next-MLX-4bit|big coder, runs alone - 45 GB
MODEL_LIST

printf '\nDownloaded so far:\n'
du -sh "$MODELS"/* 2>/dev/null || true
printf '\n============================================================\n'
if [[ "$FAILED" -eq 0 ]]; then
  printf ' STEP 02 COMPLETE. Now paste Step 03.\n'
else
  printf ' %s model(s) did not finish. Paste Step 02 again to continue.\n' "$FAILED"
fi
printf '============================================================\n'
DAN_STEP_02
