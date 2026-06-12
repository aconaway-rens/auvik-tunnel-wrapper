// AuvikTunnelMenu.swift
//
// A menu bar app that shows active Auvik tunnels and lets you disconnect them.
// It is a thin UI over `tunnelctl`: it polls `tunnelctl json` for status and
// calls `tunnelctl stop ...` to disconnect. All tunnel logic lives in tunnelctl.
//
// Build with build.sh (swiftc -parse-as-library + .app bundle + ad-hoc sign).

import SwiftUI
import AppKit

// One tunnel (saved and/or running), as emitted by `tunnelctl json`.
struct Tunnel: Identifiable, Decodable, Equatable {
    var id: String { file }
    let tenant: String
    let device: String
    let remotePort: Int
    let localPort: Int
    let url: String
    let running: Bool
    let pids: [Int]
    let uptime: String
    let file: String
}

@MainActor
final class TunnelStore: ObservableObject {
    @Published var tunnels: [Tunnel] = []
    @Published var autoPruneEnabled: Bool = true

    var active: [Tunnel] { tunnels.filter { $0.running } }
    var saved: [Tunnel] { tunnels.filter { !$0.running } }

    private var timer: Timer?
    private let ctl = NSHomeDirectory() + "/.auvik-tunnel-wrapper/bin/tunnelctl"
    private let pruneFlag = NSHomeDirectory() + "/.auvik-tunnel-wrapper/autoprune.disabled"

    init() { start() }

    func start() {
        refresh()
        let t = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() {
        let ctl = self.ctl
        let flag = self.pruneFlag
        Task.detached {
            let out = Self.run(["/bin/zsh", ctl, "json"])
            var parsed: [Tunnel] = []
            if let data = out.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([Tunnel].self, from: data) {
                parsed = decoded.sorted { $0.localPort < $1.localPort }
            }
            let result = parsed
            let pruneOn = !FileManager.default.fileExists(atPath: flag)
            await MainActor.run {
                self.tunnels = result
                self.autoPruneEnabled = pruneOn
            }
        }
    }

    func toggleAutoPrune() {
        let ctl = self.ctl
        let arg = autoPruneEnabled ? "off" : "on"
        autoPruneEnabled.toggle()   // optimistic; refresh re-reads the truth
        Task.detached {
            _ = Self.run(["/bin/zsh", ctl, "autoprune", arg])
            await MainActor.run { self.refresh() }
        }
    }

    func pruneNow() {
        let ctl = self.ctl
        Task.detached {
            _ = Self.run(["/bin/zsh", ctl, "prune"])
            await MainActor.run { self.refresh() }
        }
    }

    func disconnect(_ t: Tunnel) {
        let ctl = self.ctl
        let port = String(t.localPort)
        Task.detached {
            _ = Self.run(["/bin/zsh", ctl, "stop", port])
            await MainActor.run { self.refresh() }
        }
    }

    func disconnectAll() {
        let ctl = self.ctl
        Task.detached {
            _ = Self.run(["/bin/zsh", ctl, "stop", "all"])
            await MainActor.run { self.refresh() }
        }
    }

    func reconnect(_ t: Tunnel) {
        let ctl = self.ctl
        let name = t.file
        Task.detached {
            _ = Self.run(["/bin/zsh", ctl, "start", name])
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self.refresh() }
        }
    }

    func openInBrowser(_ t: Tunnel) {
        guard !t.url.isEmpty, let u = URL(string: t.url) else { return }
        NSWorkspace.shared.open(u)
    }

    // Run a command, return its stdout. Off the main actor so the UI never blocks.
    nonisolated static func run(_ argv: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0])
        p.arguments = Array(argv.dropFirst())
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        env["HOME"] = NSHomeDirectory()
        p.environment = env
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct MenuContent: View {
    @ObservedObject var store: TunnelStore

    var body: some View {
        if store.tunnels.isEmpty {
            Text("No tunnels")
        }

        if !store.active.isEmpty {
            Text("Active")
            ForEach(store.active) { t in
                Menu("\(t.tenant)  ·  :\(t.localPort)") {
                    Text("\(t.device):\(t.remotePort)")
                    Text("up \(t.uptime)")
                    if !t.url.isEmpty {
                        Button("Open \(t.url)") { store.openInBrowser(t) }
                    }
                    Divider()
                    Button("Disconnect") { store.disconnect(t) }
                }
            }
            Button("Disconnect All (\(store.active.count))") { store.disconnectAll() }
        }

        if !store.saved.isEmpty {
            Divider()
            Menu("Reconnect") {
                ForEach(store.saved) { t in
                    Button("\(t.tenant)  ·  :\(t.localPort)") { store.reconnect(t) }
                }
            }
        }

        Divider()
        Button("Refresh now") { store.refresh() }
        Button("Open Tunnels Folder…") {
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/auvik-tunnels"))
        }
        Button("Open Watcher Log…") {
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.auvik-tunnel-wrapper/watch.log"))
        }

        Divider()
        Toggle("Auto-prune stale files", isOn: Binding(
            get: { store.autoPruneEnabled },
            set: { _ in store.toggleAutoPrune() }))
        Button("Prune stale files now") { store.pruneNow() }

        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}

@main
struct AuvikTunnelMenuApp: App {
    @StateObject private var store = TunnelStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store)
        } label: {
            Image(systemName: store.active.isEmpty
                  ? "point.3.connected.trianglepath.dotted"
                  : "point.3.filled.connected.trianglepath.dotted")
            if !store.active.isEmpty {
                Text("\(store.active.count)")
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
