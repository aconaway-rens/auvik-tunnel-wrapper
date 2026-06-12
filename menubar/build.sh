#!/bin/zsh
#
# build.sh — compile AuvikTunnelMenu.swift into a menu bar .app, ad-hoc sign it,
# install it to ~/Applications, and set it to launch at login (and now).
#
# The app is a thin UI over tunnelctl, so install the main wrapper first
# (../install.sh) — that's where tunnelctl lives.

emulate -L zsh
set -eu

SRC_DIR="${0:A:h}"
APP_NAME="Auvik Tunnel Menu"
BUNDLE_ID="com.redeye.auvik-tunnel-menu"
APP="$HOME/Applications/$APP_NAME.app"
MACOS="$APP/Contents/MacOS"
EXE_NAME="AuvikTunnelMenu"
EXE="$MACOS/$EXE_NAME"
LABEL="$BUNDLE_ID"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# 1. Build the bundle.
rm -rf "$APP"
mkdir -p "$MACOS"

# -parse-as-library is required so @main is honored (the file has no top-level code).
swiftc -O -parse-as-library \
  "$SRC_DIR/AuvikTunnelMenu.swift" -o "$EXE" \
  -framework SwiftUI -framework AppKit

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>                <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>         <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>          <string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key>          <string>$EXE_NAME</string>
  <key>CFBundlePackageType</key>         <string>APPL</string>
  <key>CFBundleShortVersionString</key>  <string>1.0</string>
  <key>CFBundleVersion</key>             <string>1</string>
  <key>LSMinimumSystemVersion</key>      <string>13.0</string>
  <key>LSUIElement</key>                 <true/>
  <key>NSHighResolutionCapable</key>     <true/>
</dict>
</plist>
EOF

# 2. Ad-hoc sign so macOS will run it locally.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

# 3. Launch agent: start at login (and now). KeepAlive is false so the menu's
#    Quit actually quits until next login.
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>           <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$EXE</string>
  </array>
  <key>RunAtLoad</key>       <true/>
  <key>KeepAlive</key>       <false/>
</dict>
</plist>
EOF

# 4. (Re)load and launch it now.
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
open "$APP" 2>/dev/null || true

print -r -- "Built and launched: $APP"
print -r -- "  agent: $PLIST  (starts at login)"
print -r -- "Look for the network icon in your menu bar."
