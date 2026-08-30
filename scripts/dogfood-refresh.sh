#!/bin/bash
# Meal Memory — dogfood provisioning refresh.
#
# Free Apple developer accounts mint provisioning profiles that expire after
# SEVEN DAYS. When one lapses the app stops launching on Rachel's phone
# ("Unable to Verify App") until it is rebuilt and reinstalled. This rebuilds
# and reinstalls before that happens.
#
# Runs daily via launchd, but does real work only when the profile is close to
# expiring — a daily trigger gives several chances to catch the phone on the
# network, without pointless rebuilds.
#
# Deliberately does NO git operations. It builds whatever is checked out in its
# own worktree, because renewal needs a fresh profile, not new code. That keeps
# the job away from your working tree and makes it impossible for it to merge,
# switch branches, or lose work while you are mid-task.
#
# To ship new code to the phone, update the worktree yourself:
#   git -C ~/.meal-memory-dogfood/worktree merge dogfood-rachel-v2

set -uo pipefail

BASE="$HOME/.meal-memory-dogfood"
WORKTREE="$BASE/worktree"
DERIVED="$BASE/DerivedData"
LOG="$BASE/refresh.log"
APP="$DERIVED/Build/Products/Debug-iphoneos/MealMemory.app"

DEVICE_UDID="00008110-0006383C3C78801E"   # Rachel's iPhone 13 mini
TEAM="Q3JN42F5ST"                          # Puneet Jain (Personal Team)
BUNDLE_ID="com.puneetjain.mealmemory"
RENEW_WITHIN_DAYS="${RENEW_WITHIN_DAYS:-3}"                        # rebuild when the profile has ≤ this left

XCODEBUILD=/usr/bin/xcodebuild
XCRUN=/usr/bin/xcrun
PLISTBUDDY=/usr/libexec/PlistBuddy

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# Keep the log from growing without bound.
if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 1000000 ]; then
  tail -n 500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

log "--- refresh check ---"

# ── 1. Is a rebuild actually needed? ────────────────────────────────────────
# The embedded profile in the last build we installed is the best local proxy
# for what is on the phone.
# NOTE: PlistBuddy cannot read /dev/stdin, so the decoded profile must go
# through a real file. Verified — reading from a pipe silently yields
# "Error Reading File", which would have made every run think the profile was
# expired and rebuild daily.
profile_expiry() {
  local prof="$1" tmp exp
  [ -f "$prof" ] || return 1
  tmp=$(mktemp /tmp/mmprof.XXXXXX.plist) || return 1
  security cms -D -i "$prof" > "$tmp" 2>/dev/null
  exp=$("$PLISTBUDDY" -c "Print :ExpirationDate" "$tmp" 2>/dev/null)
  rm -f "$tmp"
  [ -n "$exp" ] && echo "$exp"
}

days_left=-1
if [ -f "$APP/embedded.mobileprovision" ]; then
  exp=$(profile_expiry "$APP/embedded.mobileprovision")
  if [ -n "$exp" ]; then
    exp_epoch=$(date -j -f "%a %b %d %T %Z %Y" "$exp" "+%s" 2>/dev/null)
    if [ -n "$exp_epoch" ]; then
      days_left=$(( (exp_epoch - $(date +%s)) / 86400 ))
      log "profile expires in ${days_left}d ($exp)"
    fi
  fi
fi

if [ "$days_left" -gt "$RENEW_WITHIN_DAYS" ]; then
  log "still valid — nothing to do"
  exit 0
fi

# ── 2. Is the phone reachable? ──────────────────────────────────────────────
# Wireless only works when it is on the same network and awake. If not, exit
# quietly; tomorrow's run will try again. There is a whole week of margin.
if ! timeout 60 "$XCRUN" devicectl device info lockState --device "$DEVICE_UDID" >/dev/null 2>&1; then
  log "phone not reachable — will retry on the next run"
  exit 0
fi
log "phone reachable"

# ── 3. Build (mints a fresh 7-day profile) ──────────────────────────────────
log "building…"
build_raw=$("$XCODEBUILD" -project "$WORKTREE/MealMemory.xcodeproj" \
  -scheme MealMemory \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic \
  build 2>&1)
build_out=$(echo "$build_raw" | grep -E "error:|BUILD (SUCCEEDED|FAILED)")

if [[ "$build_out" != *"BUILD SUCCEEDED"* ]]; then
  log "BUILD FAILED:"
  echo "$build_out" | head -20 | sed 's/^/    /' >> "$LOG"
  log "note: signing needs the login keychain unlocked and a valid Xcode session."
  exit 1
fi
log "build ok"

# ── 4. Install, with retries ────────────────────────────────────────────────
# Wireless transfers drop often enough that a single attempt is unreliable —
# roughly every other install failed by hand. A dropped transfer fails the
# install outright rather than degrading, so just retry.
installed=false
for attempt in 1 2 3 4; do
  # NOTE: capture into a variable and match with [[ ]] — no pipeline. Piping
  # straight into `grep -q` makes grep exit on first match, SIGPIPEs devicectl,
  # and `pipefail` then reports the whole pipeline as failed, so every
  # successful install was logged as a failure. Caught by running this for real.
  install_out=$(timeout 400 "$XCRUN" devicectl device install app --device "$DEVICE_UDID" "$APP" 2>&1)
  if [[ "$install_out" == *"App installed"* ]]; then
    log "installed (attempt $attempt)"
    installed=true
    break
  fi
  log "install attempt $attempt failed"
  sleep 15
done

if [ "$installed" != true ]; then
  log "INSTALL FAILED after 4 attempts"
  exit 1
fi

# ── 5. Launch if unlocked (best effort — she may just tap the icon) ─────────
lock_out=$(timeout 45 "$XCRUN" devicectl device info lockState --device "$DEVICE_UDID" 2>&1)
if [[ "$lock_out" == *"passcodeRequired: false"* ]]; then
  timeout 90 "$XCRUN" devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 \
    && log "launched" || log "launch skipped"
else
  log "phone locked — not launching (install is what matters)"
fi

log "done — new profile expires $(profile_expiry "$APP/embedded.mobileprovision")"
