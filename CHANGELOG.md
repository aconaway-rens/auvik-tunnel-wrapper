# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Configurable AuvikTunnel binary path** — the path is now persisted to
  `~/.auvik-tunnel-wrapper/auvik-bin` and read by the watcher daemon, the shared
  launcher, and `tunnelctl`. `install.sh` resolves it (env → auto-detect →
  prompt on a terminal) and saves it, warning instead of silently proceeding
  when it can't be found. New `tunnelctl bin [<path>|--clear]` sets/shows/clears
  it without reinstalling. Fixes the gap where a shell-exported `AUVIK_BIN` was
  invisible to the launchd watcher.
- **Host aliases** — `tunnelctl alias <device> <name>` maps a tunnel target
  (usually a bare IP) to a friendly name, stored in
  `~/.auvik-tunnel-wrapper/hostnames` and keyed by host so it applies to every
  tunnel pointing at that host. Surfaced in `tunnelctl json` and the menu bar
  app's new **Rename Host…** action (Active submenu and Reconnect entries).

### Changed
- Menu bar labels now read `tenant · host · :localport` (host shows the alias
  when set, otherwise the device IP), making same-tenant tunnels easy to tell
  apart.

### Fixed
- Port numbers in the menu no longer render with a thousands separator (e.g.
  `:24547`, not `:24,547`) — they were being formatted as localized numbers.

## [1.0.0] - 2026-06-15

Initial public release.

### Added
- **Watcher daemon** (`auvik-tunnel-watch.sh`) — a launchd-managed zsh polling
  agent that watches `~/auvik-tunnels` and runs `AuvikTunnel` on each new
  `.tunnel` file. Polls (rather than using flaky `WatchPaths`) and watches a
  non-TCC-protected folder so a background agent can actually read it.
- **Auto-open browser** — once a tunnel's local port is listening, opens the
  default browser at `http(s)://127.0.0.1:<port>` (skips non-web ports like SSH
  and RDP, which are logged instead).
- **`tunnelctl` CLI** — `list`, `start` (reconnect a saved tunnel), `stop`
  (by port/name/all), `prune`, `autoprune`, and `json`.
- **Shared launcher** (`auvik-launch.sh`) — single launch implementation used by
  both the watcher and `tunnelctl start`, so behavior never drifts.
- **Menu bar app** (`menubar/AuvikTunnelMenu.swift`) — SwiftUI `MenuBarExtra`
  showing active tunnels with Open/Disconnect/Disconnect-All, a Reconnect
  submenu for saved tunnels, and an auto-prune toggle + manual prune.
- **Auto-prune** — removes `.tunnel` files older than `AUVIK_TTL_HOURS`
  (default 24h) to Trash; never touches a running tunnel; runtime-toggleable.
- **Persistence across restarts** — `AbandonProcessGroup` keeps tunnels alive
  when the daemon reloads.
- `install.sh` / `uninstall.sh`, configurable via environment variables
  (`AUVIK_WATCH_DIR`, `AUVIK_LAUNCH_MODE`, `AUVIK_OPEN_BROWSER`, `AUVIK_PERSIST`,
  `AUVIK_TTL_HOURS`, `AUVIK_PRUNE_DISPOSAL`, `AUVIK_BIN`).

[1.0.0]: https://github.com/aconaway-rens/auvik-tunnel-wrapper/releases/tag/v1.0.0
