#!/bin/zsh
#
# auvik-tunnel-watch.sh
#
# Watches a folder for new *.tunnel files and runs AuvikTunnel against each one.
# Auvik credentials come from ~/.auvik_tunnelrc, so this needs no prompt.
#
# Run modes:
#   ./auvik-tunnel-watch.sh            one scan, then exit (handy for testing)
#   ./auvik-tunnel-watch.sh --watch    poll forever (this is how launchd runs it)
#
# Why polling instead of launchd WatchPaths: WatchPaths does not reliably deliver
# events for new files dropped into a busy directory like ~/Downloads on current
# macOS. A small poll loop is boring and dependable.
#
# Dedupe key = path + mtime + size. A new name or a re-download (new mtime) is
# treated as new; the same file seen again is skipped. Launched keys are
# persisted to $PROCESSED so dedupe survives restarts; install.sh seeds it with
# the files already in Downloads so only NEW downloads ever launch.
#
# Config via env (all optional):
#   AUVIK_BIN           AuvikTunnel binary  (auto: ~/auvik/Auvik Tunnel/AuvikTunnel,
#                       then ~/Downloads/AuvikTunnel)
#   AUVIK_WATCH_DIR     folder to watch     (default ~/auvik-tunnels)
#   AUVIK_STATE_DIR     state/logs dir      (default ~/.auvik-tunnel-wrapper)
#   AUVIK_LAUNCH_MODE   headless (default) | terminal
#   AUVIK_INTERVAL      poll seconds        (default 3)
#   AUVIK_OPEN_BROWSER  1 (default) | 0     once a tunnel is listening, open the
#                       default browser at http(s)://127.0.0.1:<local-port>
#   AUVIK_PERSIST       0 (default) | 1     pass -r so listeners stay up until
#                       explicitly stopped (else they close with the connection)

emulate -L zsh
set -u

# Prefer the installed client location; fall back to a copy in Downloads.
if [[ -z "${AUVIK_BIN:-}" ]]; then
  for _cand in "$HOME/auvik/Auvik Tunnel/AuvikTunnel" "$HOME/Downloads/AuvikTunnel"; do
    [[ -x "$_cand" ]] && { AUVIK_BIN="$_cand"; break; }
  done
fi
AUVIK_BIN="${AUVIK_BIN:-$HOME/auvik/Auvik Tunnel/AuvikTunnel}"
WATCH_DIR="${AUVIK_WATCH_DIR:-$HOME/Downloads}"
STATE_DIR="${AUVIK_STATE_DIR:-$HOME/.auvik-tunnel-wrapper}"
LAUNCH_MODE="${AUVIK_LAUNCH_MODE:-headless}"
INTERVAL="${AUVIK_INTERVAL:-3}"
OPEN_BROWSER="${AUVIK_OPEN_BROWSER:-1}"
PERSIST="${AUVIK_PERSIST:-0}"   # 1 => pass -r so listeners stay up until stopped
PROCESSED="$STATE_DIR/processed.log"
LOG="$STATE_DIR/watch.log"

mkdir -p "$STATE_DIR"
touch "$PROCESSED" "$LOG"

log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S')  $*" >>"$LOG"; }

# In-memory set of keys we've already handled this run (launched OR skipped),
# so we don't re-log the same file every poll. Preloaded from the persisted
# launched-keys so restarts stay quiet too.
typeset -A seen
while IFS= read -r line; do
  [[ -n "$line" ]] && seen[$line]=1
done < "$PROCESSED"

bin_warned=0  # throttle the "binary missing" warning to once per occurrence

# All launch behavior (AuvikTunnel invocation + browser open) lives in the shared
# launcher, so the watcher and `tunnelctl start` stay identical.
LAUNCHER="${0:A:h}/auvik-launch.sh"

launch_tunnel() {
  zsh "$LAUNCHER" "$1"
}

scan_once() {
  setopt local_options null_glob
  local f mtime size key
  for f in "$WATCH_DIR"/*.tunnel; do
    mtime=$(stat -f %m "$f"); size=$(stat -f %z "$f")
    key="$f"$'\t'"$mtime"$'\t'"$size"
    [[ -n "${seen[$key]:-}" ]] && continue

    # Must be a complete, real tunnel descriptor before we launch it.
    if ! grep -q 'tunnel-config' -- "$f"; then
      log "SKIP (not a valid/complete tunnel file yet): $f"
      seen[$key]=1
      continue
    fi

    if [[ ! -x "$AUVIK_BIN" ]]; then
      (( bin_warned )) || { log "ERROR: AuvikTunnel not executable at $AUVIK_BIN; will retry"; bin_warned=1; }
      continue   # don't mark seen: retry once the binary is back
    fi
    bin_warned=0

    launch_tunnel "$f"
    print -r -- "$key" >>"$PROCESSED"
    seen[$key]=1
  done
}

if [[ "${1:-}" == "--watch" ]]; then
  log "watcher started (poll ${INTERVAL}s, mode=${LAUNCH_MODE}, dir=${WATCH_DIR})"
  { setopt local_options null_glob; _probe=("$WATCH_DIR"/*.tunnel); log "DEBUG: can see ${#_probe} .tunnel file(s) in $WATCH_DIR"; }
  CTL="${0:A:h}/tunnelctl"
  zsh "$CTL" prune --auto >/dev/null 2>&1   # purge stale files at startup...
  last_prune=$SECONDS
  while true; do
    scan_once
    if (( SECONDS - last_prune >= 3600 )); then   # ...then hourly
      zsh "$CTL" prune --auto >/dev/null 2>&1
      last_prune=$SECONDS
    fi
    sleep "$INTERVAL"
  done
else
  scan_once
fi
