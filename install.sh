#!/bin/zsh
#
# install.sh — install the Auvik tunnel folder-watcher as a launchd agent.
#
# Copies the watcher to a stable local path (NOT OneDrive, which can be
# cloud-only/offline), seeds the dedupe list so only NEW files trigger, then
# loads a long-lived polling launchd agent.
#
# It watches a DEDICATED, non-TCC-protected folder ($WATCH_DIR, default
# ~/auvik-tunnels) rather than ~/Downloads: a launchd agent has no access to the
# protected ~/Downloads/~/Desktop/~/Documents folders, so its directory scan
# comes back empty there. Point your browser's .tunnel downloads at this folder.

emulate -L zsh
set -eu

SRC_DIR="${0:A:h}"
STATE_DIR="$HOME/.auvik-tunnel-wrapper"
BIN_DIR="$STATE_DIR/bin"
SCRIPT="$BIN_DIR/auvik-tunnel-watch.sh"
PROCESSED="$STATE_DIR/processed.log"
WATCH_DIR="${AUVIK_WATCH_DIR:-$HOME/auvik-tunnels}"
LAUNCH_MODE="${AUVIK_LAUNCH_MODE:-headless}"
TTL_HOURS="${AUVIK_TTL_HOURS:-24}"   # auto-prune .tunnel files older than this (0 = off)
LABEL="com.redeye.auvik-tunnel-watch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$BIN_DIR" "$WATCH_DIR"
touch "$PROCESSED"

# 1. Install the watcher, the shared launcher, and tunnelctl to a stable location.
cp "$SRC_DIR/auvik-tunnel-watch.sh" "$SCRIPT"
chmod +x "$SCRIPT"
cp "$SRC_DIR/auvik-launch.sh" "$BIN_DIR/auvik-launch.sh"
chmod +x "$BIN_DIR/auvik-launch.sh"
cp "$SRC_DIR/tunnelctl" "$BIN_DIR/tunnelctl"
chmod +x "$BIN_DIR/tunnelctl"
# Symlink tunnelctl onto PATH if a common bin dir is writable (no sudo).
TUNNELCTL_LINK=""
for d in "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin; do
  if [[ -d "$d" && -w "$d" ]]; then ln -sf "$BIN_DIR/tunnelctl" "$d/tunnelctl"; TUNNELCTL_LINK="$d/tunnelctl"; break; fi
done

# 1b. Resolve and persist the AuvikTunnel binary path. The watcher runs under
#     launchd and never sees a shell-exported AUVIK_BIN, so we save the path to
#     $STATE_DIR/auvik-bin, which every entry point reads. Honors AUVIK_BIN, then
#     auto-detects, then (on a terminal) prompts. Never fatal: the binary may be
#     installed later, and `tunnelctl bin <path>` can set it after the fact.
BIN_CONF="$STATE_DIR/auvik-bin"
AUVIK_BIN_PATH="${AUVIK_BIN:-}"
AUVIK_BIN_PATH="${AUVIK_BIN_PATH/#\~/$HOME}"
if [[ -z "$AUVIK_BIN_PATH" || ! -x "$AUVIK_BIN_PATH" ]]; then
  for c in "$HOME/auvik/Auvik Tunnel/AuvikTunnel" "$HOME/Downloads/AuvikTunnel"; do
    [[ -x "$c" ]] && { AUVIK_BIN_PATH="$c"; break; }
  done
fi
if [[ ( -z "$AUVIK_BIN_PATH" || ! -x "$AUVIK_BIN_PATH" ) && -t 0 ]]; then
  print -r -- "Could not find the AuvikTunnel binary (a file you downloaded from Auvik)."
  print -rn -- "Path to AuvikTunnel (blank to skip for now): "
  read -r reply || reply=""
  AUVIK_BIN_PATH="${reply/#\~/$HOME}"
fi
if [[ -n "$AUVIK_BIN_PATH" && -x "$AUVIK_BIN_PATH" ]]; then
  AUVIK_BIN_PATH="${AUVIK_BIN_PATH:A}"   # absolute
  print -r -- "$AUVIK_BIN_PATH" >"$BIN_CONF"
else
  AUVIK_BIN_PATH=""   # mark unresolved for the final report
fi

# 2. Mark any .tunnel files already in the watch folder as "already handled"
#    (fresh), so only NEW files dropped in after this point will launch.
setopt null_glob
: >"$PROCESSED"
for f in "$WATCH_DIR"/*.tunnel; do
  mtime=$(stat -f %m "$f"); size=$(stat -f %z "$f")
  printf '%s\t%s\t%s\n' "$f" "$mtime" "$size" >>"$PROCESSED"
done

# 3. Write the launchd agent: a long-lived polling daemon (KeepAlive). Polling
#    is used instead of WatchPaths, which doesn't reliably fire for new files on
#    current macOS. WATCH_DIR / LAUNCH_MODE are passed via EnvironmentVariables.
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>$SCRIPT</string>
    <string>--watch</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>AUVIK_WATCH_DIR</key>    <string>$WATCH_DIR</string>
    <key>AUVIK_LAUNCH_MODE</key>  <string>$LAUNCH_MODE</string>
    <key>AUVIK_OPEN_BROWSER</key> <string>${AUVIK_OPEN_BROWSER:-1}</string>
    <key>AUVIK_TTL_HOURS</key>    <string>$TTL_HOURS</string>
  </dict>
  <key>RunAtLoad</key>         <true/>
  <key>KeepAlive</key>         <true/>
  <!-- Don't kill running tunnels when the daemon restarts/crashes. -->
  <key>AbandonProcessGroup</key> <true/>
  <key>StandardOutPath</key>   <string>$STATE_DIR/launchd.out.log</string>
  <key>StandardErrorPath</key> <string>$STATE_DIR/launchd.err.log</string>
</dict>
</plist>
EOF

# 4. (Re)load it.
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

print -r -- "Installed and watching $WATCH_DIR for new *.tunnel files (mode=$LAUNCH_MODE)."
print -r -- "  script:  $SCRIPT"
print -r -- "  agent:   $PLIST"
print -r -- "  logs:    $STATE_DIR/watch.log"
if [[ -n "$AUVIK_BIN_PATH" ]]; then
  print -r -- "  binary:  $AUVIK_BIN_PATH"
else
  print -r -- "  binary:  NOT FOUND — tunnels won't launch until you point us at AuvikTunnel:"
  print -r -- "             tunnelctl bin /path/to/AuvikTunnel"
  print -r -- "           (or re-run: AUVIK_BIN=/path/to/AuvikTunnel ./install.sh)"
fi
if [[ -n "$TUNNELCTL_LINK" ]]; then
  print -r -- "  control: $TUNNELCTL_LINK   (run: tunnelctl list | tunnelctl stop <port|all>)"
else
  print -r -- "  control: $BIN_DIR/tunnelctl   (no PATH dir was writable; alias it or call by full path)"
fi
print -r -- ""
print -r -- "Next: point your browser's .tunnel downloads at  $WATCH_DIR"
