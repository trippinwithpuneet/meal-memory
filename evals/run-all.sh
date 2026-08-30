#!/usr/bin/env bash
# Meal Memory eval runner — every layer, one scorecard.
#
#   ./evals/run-all.sh            # everything available on this machine
#   ./evals/run-all.sh fast       # skip the simulator layers (~4 min faster)
#   ./evals/run-all.sh backend    # backend + copy lint only
#
# Environment:
#   SIM_NAME            simulator to use (default "iPhone 13 mini" — the base
#                       device for this project; smallest current screen)
#   ANTHROPIC_API_KEY   enables the LLM parse-tail eval; skipped without it
#
# Exit code is non-zero if any layer fails. Failures tagged [FINDING] in the
# suites are known open bugs, documented in docs/reference-evals.md — they are
# real, not flakes, and are expected to stay red until fixed.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MODE="${1:-all}"
SIM_NAME="${SIM_NAME:-iPhone 13 mini}"
DERIVED="${TMPDIR:-/tmp}/meal-memory-evals-dd"

BAR="══════════════════════════════════════════════════════════════════════════════"
declare -a NAMES STATUSES DETAILS

run_layer() {
  local name="$1"; shift
  local detail_cmd="$1"; shift
  echo ""
  echo "$BAR"
  echo "▶ $name"
  echo "$BAR"
  if "$@"; then
    NAMES+=("$name"); STATUSES+=("PASS"); DETAILS+=("$detail_cmd")
  else
    NAMES+=("$name"); STATUSES+=("FAIL"); DETAILS+=("$detail_cmd")
  fi
}

skip_layer() {
  NAMES+=("$1"); STATUSES+=("SKIP"); DETAILS+=("$2")
  echo ""
  echo "$BAR"
  echo "⃠ $1 — SKIPPED ($2)"
  echo "$BAR"
}

# ─── Backend ─────────────────────────────────────────────────────────────────

if ! command -v bun >/dev/null 2>&1; then
  skip_layer "BE unit (fetch-recipe helpers)" "bun not installed"
  skip_layer "BE extraction eval (JSON-LD)"   "bun not installed"
  skip_layer "BE LLM parse-tail eval"          "bun not installed"
  skip_layer "UX copy lint"                    "bun not installed"
else
  run_layer "BE unit (fetch-recipe helpers)" "bun test evals/backend" \
    bun test evals/backend

  run_layer "BE extraction eval (JSON-LD)" "bun run evals/backend/extraction.eval.ts" \
    bun run evals/backend/extraction.eval.ts

  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    run_layer "BE LLM parse-tail eval" "bun run evals/backend/llm.eval.ts" \
      bun run evals/backend/llm.eval.ts
  else
    skip_layer "BE LLM parse-tail eval" "ANTHROPIC_API_KEY not set"
  fi

  run_layer "UX copy lint" "bun run evals/ux/copy-lint.ts" \
    bun run evals/ux/copy-lint.ts
fi

# ─── Database ────────────────────────────────────────────────────────────────

if [ "$MODE" = "backend" ]; then
  skip_layer "DB pgTAP (RLS + invites)" "mode=backend"
elif docker info >/dev/null 2>&1; then
  run_layer "DB pgTAP (RLS + invites)" "supabase test db" \
    "$HOME/.local/share/supabase/supabase" test db
else
  skip_layer "DB pgTAP (RLS + invites)" "Docker not running — start it, then: supabase test db"
fi

# ─── Frontend + UX flows (simulator) ─────────────────────────────────────────

if [ "$MODE" = "fast" ] || [ "$MODE" = "backend" ]; then
  skip_layer "FE unit (view models, decoding, copy)" "mode=$MODE"
  skip_layer "UX flows (XCUITest, demo mode)"        "mode=$MODE"
elif ! command -v xcodebuild >/dev/null 2>&1; then
  skip_layer "FE unit (view models, decoding, copy)" "xcodebuild not available"
  skip_layer "UX flows (XCUITest, demo mode)"        "xcodebuild not available"
else
  DEST="platform=iOS Simulator,name=$SIM_NAME"

  run_layer "FE unit (view models, decoding, copy)" \
    "xcodebuild test -only-testing:MealMemoryTests" \
    xcodebuild test -project MealMemory.xcodeproj -scheme MealMemory \
      -destination "$DEST" -derivedDataPath "$DERIVED" \
      -only-testing:MealMemoryTests -quiet

  run_layer "UX flows (XCUITest, demo mode)" \
    "xcodebuild test -only-testing:MealMemoryUITests" \
    xcodebuild test -project MealMemory.xcodeproj -scheme MealMemory \
      -destination "$DEST" -derivedDataPath "$DERIVED" \
      -only-testing:MealMemoryUITests -quiet
fi

# ─── Scorecard ───────────────────────────────────────────────────────────────

echo ""
echo "$BAR"
echo "  MEAL MEMORY EVAL SCORECARD"
echo "$BAR"

failed=0
skipped=0
for i in "${!NAMES[@]}"; do
  status="${STATUSES[$i]}"
  case "$status" in
    PASS) icon="✓" ;;
    FAIL) icon="✗"; failed=$((failed + 1)) ;;
    *)    icon="–"; skipped=$((skipped + 1)) ;;
  esac
  printf "  %s  %-6s %-42s %s\n" "$icon" "$status" "${NAMES[$i]}" "${DETAILS[$i]}"
done

echo "$BAR"
if [ "$failed" -eq 0 ]; then
  echo "  All executed layers passed. ($skipped skipped)"
else
  echo "  $failed layer(s) failed, $skipped skipped."
  echo "  Failures tagged [FINDING] are documented open bugs, not flakes —"
  echo "  see docs/reference-evals.md."
fi
echo "$BAR"
echo ""

exit $([ "$failed" -eq 0 ] && echo 0 || echo 1)
