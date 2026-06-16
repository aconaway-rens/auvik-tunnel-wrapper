# Auvik Tunnel Wrapper

Auto-launches the Auvik tunnel client whenever a new `.tunnel` file appears in a
watched folder, so you never have to run it against `AuvikTunnel` by hand — with
a `tunnelctl` CLI and a macOS menu bar app to manage, reconnect, and clean up
tunnels.

A launchd agent runs a small zsh polling daemon. When a new `*.tunnel` file
shows up in the watch folder, it runs `AuvikTunnel <file>` against it.
Credentials come from `~/.auvikrc` / `~/.auvik_tunnelrc` (already set up by the
Auvik client), so there are no prompts.

> **Unofficial.** This is a personal helper around Auvik's tunnel client. It is
> not affiliated with, endorsed by, or supported by Auvik. Use at your own risk.

## Requirements

- macOS (developed on macOS 26; the menu bar app needs macOS 13+).
- The **Auvik Tunnel client** already installed and authenticated — i.e. the
  `AuvikTunnel` binary plus `~/.auvikrc` / `~/.auvik_tunnelrc` credentials, which
  Auvik creates when you first set up remote tunnels. This wrapper does **not**
  perform Auvik auth; it reuses what the client already stored.
- `zsh` (the macOS default shell).
- Xcode Command Line Tools (`swiftc`) — only for the optional menu bar app.

## Quick start

```sh
git clone https://github.com/aconaway-rens/auvik-tunnel-wrapper.git
cd auvik-tunnel-wrapper
./install.sh                 # watcher daemon + tunnelctl
cd menubar && ./build.sh     # optional menu bar app
```

Then set your browser to save `.tunnel` downloads to `~/auvik-tunnels` (see
[Point your browser at the folder](#point-your-browser-at-the-folder)). Download
a tunnel from Auvik and it launches automatically.

## Demo

The menu bar shows a connected-nodes icon with a count of active tunnels; the
dropdown manages them:

```
  ⧉ 2                          ← menu bar (filled icon + active count)
  ┌─────────────────────────────────────────┐
  │ Active                                   │
  │   lifefitnessazdsm · Core sw · :24547  ▸ │── Core sw:443
  │   Disconnect All (2)                     │   up 12:43
  ├──────────────────────────────────────────│   Open https://127.0.0.1:24547
  │ Reconnect                              ▸ │   ──────────
  ├──────────────────────────────────────────│   Rename Host…
  │ Refresh now                              │   Disconnect
  │ Refresh now                              │
  │ Open Tunnels Folder…                     │
  │ Open Watcher Log…                        │
  ├──────────────────────────────────────────│
  │ ☑ Auto-prune stale files                 │
  │ Prune stale files now                    │
  ├──────────────────────────────────────────│
  │ Quit                                     │
  └─────────────────────────────────────────┘
```

> Replace this with a real screenshot: open the menu and run
> `screencapture -iW ~/Desktop/menu.png`, then drop it in a `docs/` folder and
> link it here.

## Why a dedicated folder (not ~/Downloads)

macOS protects `~/Downloads`, `~/Desktop`, and `~/Documents` (TCC). A launchd
agent has no access to them, so a scan of `~/Downloads` silently returns
nothing. Instead the daemon watches **`~/auvik-tunnels`** (configurable), a
normal unprotected folder. Point your browser's `.tunnel` downloads there.

## Why polling (not WatchPaths / FSEvents)

launchd `WatchPaths` does not reliably deliver events for new files on current
macOS. A 3-second poll loop is boring and dependable; the latency is irrelevant
here.

## Install

```sh
./install.sh
```

Creates `~/auvik-tunnels`, installs the watcher to
`~/.auvik-tunnel-wrapper/bin/`, and loads the launchd agent. Override defaults:

```sh
AUVIK_WATCH_DIR=~/some/folder AUVIK_LAUNCH_MODE=terminal ./install.sh
```

## Point your browser at the folder

Set your browser to save downloads to `~/auvik-tunnels` (or enable "ask where to
save each file" and pick it for `.tunnel` files). Once a `.tunnel` lands there,
the tunnel comes up within a few seconds.

## Using a tunnel (auto-open browser)

When a tunnel comes up, the wrapper waits for the local port to start listening
and then opens your default browser at it:

- remote port 80 → `http://127.0.0.1:<local-port>`
- remote port 443 / 8443 / 11443 / other → `https://127.0.0.1:<local-port>`
- remote port 22 / 23 / 3389 / 3306 / 5432 / 5900 / 161 (ssh, rdp, db, vnc,
  snmp…) → no browser; the local port is just logged so you can point your own
  tool at `127.0.0.1:<local-port>`.

Connecting promptly also matters: AuvikTunnel exits on its own if nothing ever
connects, so the auto-open keeps the tunnel alive by using it right away.

Disable with `AUVIK_OPEN_BROWSER=0 ./install.sh`.

## Managing tunnels (`tunnelctl`)

Installed to `~/.auvik-tunnel-wrapper/bin/tunnelctl` and symlinked onto PATH.

```sh
tunnelctl                 # list running tunnels (port, target, file)
tunnelctl start saralee   # (re)launch a saved .tunnel by name/substring
tunnelctl stop 33770      # stop the tunnel on local port 33770
tunnelctl stop saralee    # stop tunnels whose filename matches
tunnelctl stop all        # stop everything
tunnelctl alias 10.0.0.1 "Core switch"  # friendly name for a host (IP)
tunnelctl alias 10.0.0.1  # show the alias; `alias` alone lists all
tunnelctl alias --clear 10.0.0.1        # remove the alias
tunnelctl bin ~/Downloads/AuvikTunnel   # point at the AuvikTunnel binary
tunnelctl json            # machine-readable status (saved + running)
```

**Host aliases:** tunnel targets are usually bare IPs, which are hard to tell
apart when several share a tenant. `tunnelctl alias` maps a device (host) to a
friendly name, stored in `~/.auvik-tunnel-wrapper/hostnames`. The name is keyed
by host, so it applies to every tunnel pointing at that host and shows up in
both `tunnelctl json` and the menu bar app (which can set it via **Rename
Host…**).

**Reconnecting:** because used `.tunnel` files are kept in `~/auvik-tunnels`,
every tunnel you've downloaded can be relaunched later with `tunnelctl start`
(or the menu bar app's **Reconnect** submenu) — download once, disconnect, and
bring it back whenever you want. Launch behavior (browser-open, persist, etc.)
is identical to a fresh download because both paths use the shared
`auvik-launch.sh`.

By default a tunnel also closes when its connection closes (e.g. you close the
browser tab). To keep listeners up until you explicitly `tunnelctl stop` them,
reinstall with persist mode: `AUVIK_PERSIST=1 ./install.sh` (verify `-r` works
with your client first).

## Menu bar app

A native SwiftUI `MenuBarExtra` app shows active tunnels and lets you disconnect
them. It's a thin UI over `tunnelctl` (polls `tunnelctl json`, calls
`tunnelctl stop`). Build/install it:

```sh
cd menubar && ./build.sh
```

This compiles `AuvikTunnelMenu.swift`, bundles + ad-hoc-signs
`~/Applications/Auvik Tunnel Menu.app`, and loads a launch agent
(`com.redeye.auvik-tunnel-menu`) so it starts at login. A network icon appears
in the menu bar with a count of active tunnels. The dropdown shows **Active**
tunnels (`tenant · host · :localport`) with **Open** / **Rename Host…** /
**Disconnect** / **Disconnect All**, plus a **Reconnect** submenu listing
saved-but-not-running tunnels you can relaunch or rename. **Rename Host…** sets a
friendly name for the host (see [Host aliases](#managing-tunnels-tunnelctl)) so IP-only
targets are easy to tell apart. It polls `tunnelctl json` every 4s. Requires the
Xcode Command Line Tools (`swiftc`). Quit from the menu; it returns at next
login.

## File lifecycle / auto-prune

A `.tunnel` file pins an Auvik session ID that expires server-side, so old files
eventually stop working and just clutter the Reconnect list. The watcher prunes
them automatically:

- Files older than **`AUVIK_TTL_HOURS`** (default **24**, by file mtime =
  download time) are removed. Set `AUVIK_TTL_HOURS=0` to disable.
- Files whose tunnel is **currently running are never touched** — they're only
  eligible once stopped.
- Disposal is **`AUVIK_PRUNE_DISPOSAL`**: `trash` (default — moves to
  `~/.Trash`, recoverable), `delete`, or `archive` (`~/auvik-tunnels/.archive`).
- Runs at daemon startup and hourly thereafter. Every removal is logged to
  `watch.log`.

Tune it at install time, e.g. keep files for 3 days:

```sh
AUVIK_TTL_HOURS=72 ./install.sh
```

Or prune on demand (also honors the env vars):

```sh
tunnelctl prune        # use the configured TTL
tunnelctl prune 8      # remove anything older than 8h
```

**Toggle auto-prune at runtime** (no reinstall): the menu bar app has an
**Auto-prune stale files** checkbox and a **Prune stale files now** item. Under
the hood that's a flag file (`~/.auvik-tunnel-wrapper/autoprune.disabled`) the
daemon checks each hour:

```sh
tunnelctl autoprune off      # pause automatic pruning
tunnelctl autoprune on       # resume
tunnelctl autoprune status   # on | off
```

When off, only the *automatic* hourly prune is paused — a manual `tunnelctl
prune` (or "Prune stale files now") still runs.

The 24h default is a starting guess — watch how long your reconnects keep
working and adjust `AUVIK_TTL_HOURS` to match Auvik's real token lifetime.

## Launch modes

- `headless` (default) — tunnel runs detached; output goes to
  `~/.auvik-tunnel-wrapper/tunnel-<name>.log`. The local listen port is parsed
  from the file and written to `watch.log`. Chosen as the default because a
  launchd agent can't reliably drive Terminal (that needs Automation consent).
- `terminal` — opens each tunnel in a Terminal window (visible port, Ctrl-C to
  close). Requires granting the agent Automation control of Terminal on first
  use. Enable with `AUVIK_LAUNCH_MODE=terminal ./install.sh`.

## Binary location

`AuvikTunnel` is a file you download from Auvik; this wrapper does not install
it. The path is resolved in this order:

1. `AUVIK_BIN` in the environment (highest priority).
2. The path you saved — via `install.sh` or `tunnelctl bin <path>` — stored in
   `~/.auvik-tunnel-wrapper/auvik-bin`. **This is what the launchd watcher uses,**
   since a background agent never sees a shell-exported `AUVIK_BIN`.
3. Auto-detection: `~/auvik/Auvik Tunnel/AuvikTunnel`, then `~/Downloads/AuvikTunnel`.

`install.sh` resolves the binary (env → auto-detect → prompt when run in a
terminal) and saves it for you. If it can't find it, install still completes and
warns you; point at it later without reinstalling:

```sh
tunnelctl bin /path/to/AuvikTunnel   # save the path (must exist + be executable)
tunnelctl bin                        # show the saved path
tunnelctl bin --clear                # forget it (back to auto-detection)
```

Changing the saved path takes effect for new launches; restart the watcher
(`./install.sh` again, or reload the launch agent) if you want the running
daemon to pick it up immediately.

## Logs

- `~/.auvik-tunnel-wrapper/watch.log` — what the watcher did (incl. local ports)
- `~/.auvik-tunnel-wrapper/tunnel-<name>.log` — per-tunnel output (headless mode)
- `~/.auvik-tunnel-wrapper/launchd.{out,err}.log` — launchd stdout/stderr

Tail it live:

```sh
tail -f ~/.auvik-tunnel-wrapper/watch.log
```

## Dedupe

Key = path + mtime + size, persisted to `~/.auvik-tunnel-wrapper/processed.log`.
A new name or a re-download (new mtime) launches; the same file seen again is
skipped. `install.sh` seeds the list with files already in the folder.

## Uninstall

```sh
./uninstall.sh
```

Removes both launch agents and quits the menu bar app. State/logs in
`~/.auvik-tunnel-wrapper/` are kept; delete that folder and
`~/Applications/Auvik Tunnel Menu.app` for a full clean-up. Running tunnels are
left up — use `tunnelctl stop all` first if you want them gone.

## Repository layout

| Path | What it is |
|------|------------|
| `install.sh` / `uninstall.sh` | Install/remove the watcher launch agent + `tunnelctl` |
| `auvik-tunnel-watch.sh` | The polling watcher daemon |
| `auvik-launch.sh` | Shared launcher (AuvikTunnel invocation + browser-open), used by the watcher *and* `tunnelctl start` |
| `tunnelctl` | CLI: `list` / `start` / `stop` / `prune` / `autoprune` / `alias` / `bin` / `json` |
| `menubar/AuvikTunnelMenu.swift` | SwiftUI menu bar app |
| `menubar/build.sh` | Compile + bundle + ad-hoc-sign + install the app |

The installed runtime lives **outside** the repo, under
`~/.auvik-tunnel-wrapper/` (a copy of the scripts plus state/logs), so the
watcher never depends on the cloned checkout.

## Technical details

**Languages.** The watcher, launcher, and `tunnelctl` are `zsh` (targeting the
macOS system `/bin/zsh`, run with `emulate -L zsh` + `set -u`). The menu bar app
is Swift / SwiftUI (`MenuBarExtra`) with a little AppKit (`NSAlert`,
`NSWorkspace`, `NSApplication`).

**Third-party dependencies.** None. There is no package manager, lockfile, or
vendored code — everything is the macOS-bundled toolchain and CLI utilities.

| Component | Needs | Notes |
|-----------|-------|-------|
| Scripts | `/bin/zsh` | Ships with macOS. |
| Menu bar app (build) | `swiftc` (Xcode Command Line Tools), `codesign` | Build-time only. |
| Menu bar app (run) | macOS 13+ | `MenuBarExtra` requires it (`LSMinimumSystemVersion 13.0`). |
| Runtime | `AuvikTunnel` | Supplied by you; see [Binary location](#binary-location). |

**System utilities used** (all part of macOS): `launchctl` (load the agents),
`ps` / `lsof` (find running tunnels and wait for a listening port), `stat`
(dedupe key + prune age), `grep` / `sed` / `awk` / `paste` (parse `.tunnel`
files), `osascript` (Terminal launch mode), and `open` (browser / Finder).

**Build.** `menubar/build.sh` compiles with
`swiftc -O -parse-as-library -framework SwiftUI -framework AppKit`
(`-parse-as-library` so `@main` is honored — the file has no top-level code),
assembles a `.app` bundle with a generated `Info.plist` (`LSUIElement` = true, so
it's a menubar-only accessory with no Dock icon), ad-hoc signs it
(`codesign --sign -`) so Gatekeeper will run it locally, and installs it to
`~/Applications`.

**Process model.** Two launchd user agents (in `~/Library/LaunchAgents`):
`com.redeye.auvik-tunnel-watch` (the polling daemon — `KeepAlive` true,
`AbandonProcessGroup` true so tunnels survive a daemon restart) and
`com.redeye.auvik-tunnel-menu` (the menu bar app — `KeepAlive` false so **Quit**
sticks until next login). `AuvikTunnel` processes are launched detached
(`nohup … & disown`) and are discovered later by scanning `ps`, so they outlive
the watcher.

**Data flow.** `tunnelctl` is the single source of truth: it parses `.tunnel`
files and the process table and emits `tunnelctl json`. The menu bar app is a
thin client that polls that JSON every 4s and shells back out to `tunnelctl` for
actions (`stop`, `start`, `alias`). No tunnel logic is duplicated in Swift.

**State** lives in `~/.auvik-tunnel-wrapper/`: `bin/` (installed copies of the
scripts), `processed.log` (dedupe keys), `hostnames` (host aliases), `auvik-bin`
(saved binary path), `autoprune.disabled` (prune toggle flag), and the logs.

**Network.** The wrapper itself makes no network calls; all tunneling and auth is
done by `AuvikTunnel`. Browser-open only ever targets `127.0.0.1`.

## Security / privacy

- No credentials are stored in this repo. Auvik's API key lives in `~/.auvikrc`
  (created by the Auvik client) and is read only by `AuvikTunnel` itself.
- `.tunnel` files contain a tenant name, a device IP, and ports — they stay on
  your machine and are not part of this repo.

## License

[MIT](LICENSE).

## Notes / ideas

- Optional macOS notification with the local port when a tunnel comes up.
- Show each saved tunnel's age in the menu's Reconnect list.
