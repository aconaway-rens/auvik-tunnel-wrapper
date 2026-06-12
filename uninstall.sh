#!/bin/zsh
# uninstall.sh — unload and remove the launchd agents (watcher + menu bar app).
# Leaves ~/.auvik-tunnel-wrapper (state/logs) in place; delete it by hand for a
# clean slate. Does not stop already-running tunnels (use: tunnelctl stop all).
emulate -L zsh
set -eu

for LABEL in com.redeye.auvik-tunnel-watch com.redeye.auvik-tunnel-menu; do
  PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  print -r -- "Removed agent: $LABEL"
done

# Quit the menu bar app if running; leave the .app bundle in ~/Applications.
pkill -f "Auvik Tunnel Menu.app/Contents/MacOS/AuvikTunnelMenu" 2>/dev/null || true

print -r -- "Done. State kept at ~/.auvik-tunnel-wrapper."
print -r -- "Tip: 'tunnelctl stop all' to drop any tunnels still running."
print -r -- "     Delete the app with: rm -rf ~/Applications/'Auvik Tunnel Menu.app'"
