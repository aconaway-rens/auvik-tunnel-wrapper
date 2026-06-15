# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project uses
[Semantic Versioning](https://semver.org/).

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
