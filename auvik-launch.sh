#!/bin/zsh
#
# auvik-launch.sh <tunnel-file>
#
# Launch AuvikTunnel against one .tunnel file, then (optionally) open the default
# browser once the local port is listening. Shared by the watcher and by
# `tunnelctl start` so launch behavior is identical everywhere.
#
# Honors: AUVIK_BIN, AUVIK_LAUNCH_MODE, AUVIK_OPEN_BROWSER, AUVIK_PERSIST,
#         AUVIK_STATE_DIR. When AUVIK_BIN is unset it reads the path saved by
#         install.sh / `tunnelctl bin` from $AUVIK_STATE_DIR/auvik-bin.

emulate -L zsh
set -u

file="${1:-}"
[[ -n "$file" && -f "$file" ]] || { print -u2 -- "usage: auvik-launch.sh <tunnel-file>"; exit 2; }

STATE_DIR="${AUVIK_STATE_DIR:-$HOME/.auvik-tunnel-wrapper}"
BIN_CONF="$STATE_DIR/auvik-bin"

# Resolve the AuvikTunnel binary. Precedence: AUVIK_BIN env, then the path saved
# by install.sh / `tunnelctl bin` ($BIN_CONF), then common install locations.
# The saved-path file is how the launchd watcher — which never sees a
# shell-exported AUVIK_BIN — learns where the user's binary lives.
if [[ -z "${AUVIK_BIN:-}" && -s "$BIN_CONF" ]]; then
  AUVIK_BIN="$(<"$BIN_CONF")"
fi
if [[ -z "${AUVIK_BIN:-}" ]]; then
  for _c in "$HOME/auvik/Auvik Tunnel/AuvikTunnel" "$HOME/Downloads/AuvikTunnel"; do
    [[ -x "$_c" ]] && { AUVIK_BIN="$_c"; break; }
  done
fi
AUVIK_BIN="${AUVIK_BIN:-$HOME/auvik/Auvik Tunnel/AuvikTunnel}"
LAUNCH_MODE="${AUVIK_LAUNCH_MODE:-headless}"
OPEN_BROWSER="${AUVIK_OPEN_BROWSER:-1}"
PERSIST="${AUVIK_PERSIST:-0}"
LOG="$STATE_DIR/watch.log"

mkdir -p "$STATE_DIR"
log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S')  $*" >>"$LOG"; }

[[ -x "$AUVIK_BIN" ]] || { log "ERROR: AuvikTunnel not executable at $AUVIK_BIN"; exit 1; }

# Browser URL for a local/remote port pair; empty for non-web ports.
web_url() {
  local lport="$1" rport="$2"
  case "$rport" in
    80)                            print -r -- "http://127.0.0.1:$lport" ;;
    22|23|3389|3306|5432|5900|161) print -r -- "" ;;
    *)                             print -r -- "https://127.0.0.1:$lport" ;;
  esac
}

# Wait (in background) for the local port to listen, then open the browser.
open_when_ready() {
  local f="$1" line lport rport url i
  grep -E 'tunnel-config' -- "$f" 2>/dev/null | while IFS= read -r line; do
    lport=$(print -r -- "$line" | sed -E 's/.*= *(tcp|udp):([0-9]+):.*/\2/')
    rport=$(print -r -- "$line" | sed -E 's/.*= *(tcp|udp):[0-9]+:[^:]+:([0-9]+):.*/\2/')
    url=$(web_url "$lport" "$rport")
    if [[ -z "$url" ]]; then
      log "tunnel up (non-web): connect to 127.0.0.1:$lport (remote :$rport)"
      continue
    fi
    for i in {1..30}; do
      /usr/sbin/lsof -nP -iTCP:"$lport" -sTCP:LISTEN >/dev/null 2>&1 && break
      sleep 0.5
    done
    log "opening $url"
    /usr/bin/open "$url"
  done
}

ports=$(grep -E 'tunnel-config' -- "$file" 2>/dev/null \
  | sed -E 's/.*= *(tcp|udp):([0-9]+):.*/\2/' | paste -sd, -)

typeset -a args; (( PERSIST )) && args+=(-r); args+=("$file")

if [[ "$LAUNCH_MODE" == "headless" ]]; then
  tlog="$STATE_DIR/tunnel-${file:t}.log"
  nohup "$AUVIK_BIN" "${args[@]}" >"$tlog" 2>&1 &
  disown
  log "LAUNCH (headless): ${file:t}  local port(s)=${ports:-?}  log=$tlog"
else
  rflag=""; (( PERSIST )) && rflag="-r "
  cmd="'$AUVIK_BIN' ${rflag}'$file'"
  /usr/bin/osascript \
    -e "tell application \"Terminal\" to do script \"$cmd\"" \
    -e "tell application \"Terminal\" to activate" \
    >/dev/null 2>&1
  log "LAUNCH (terminal): ${file:t}  local port(s)=${ports:-?}"
fi

(( OPEN_BROWSER )) && { open_when_ready "$file" &! }
