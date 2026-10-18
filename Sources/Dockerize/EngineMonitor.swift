import AppKit
import SwiftUI
import DockerizeCore

/// Watches the Docker engine: is the CLI installed, is the daemon up, and what
/// containers, images, volumes and networks exist. Probes run off the main thread.
@MainActor
final class EngineMonitor: ObservableObject {
    enum Status: Equatable {
        case checking
        case notInstalled
        case stopped
        case running(String)

        var isRunning: Bool { if case .running = self { return true } else { return false } }
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var clientVersion: String?
    @Published private(set) var state: DockerState?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isStarting = false

    let probe = DockerProbe()
    private var refreshing = false
    private var pendingRefresh = false

    /// Re-reads engine status and, if it's up, a full snapshot.
    /// Calls `then` on the main actor once the new state is published.
    func refresh(then: (@MainActor () -> Void)? = nil) {
        guard !refreshing else { pendingRefresh = true; return }
        refreshing = true
        let probe = probe
        let wantClient = clientVersion == nil
        Task.detached(priority: .utility) {
            guard probe.isInstalled else {
                await self.publish(.notInstalled, client: nil, state: nil, then: then)
                return
            }
            let client = wantClient ? probe.clientVersion() : nil
            guard let server = probe.serverVersion() else {
                await self.publish(.stopped, client: client, state: nil, then: then)
                return
            }
            let snapshot = probe.snapshot()
            await self.publish(.running(server), client: client, state: snapshot, then: then)
        }
    }

    private func publish(_ status: Status, client: String?, state: DockerState?, then: (@MainActor () -> Void)?) {
        if self.status != status { self.status = status }
        if let client { clientVersion = client }
        if self.state != state { self.state = state }
        lastUpdated = Date()
        if status.isRunning { isStarting = false }
        refreshing = false
        then?()
        if pendingRefresh {
            pendingRefresh = false
            refresh()
        }
    }

    // MARK: Starting the engine

    /// Docker runtimes we know how to open, in order of preference.
    private static let runtimes: [(name: String, path: String)] = [
        ("OrbStack", "/Applications/OrbStack.app"),
        ("Docker Desktop", "/Applications/Docker.app"),
        ("Rancher Desktop", "/Applications/Rancher Desktop.app"),
    ]

    var installedRuntime: (name: String, path: String)? {
        Self.runtimes.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Opens the installed Docker runtime. Returns false if none was found
    /// (for Colima the caller types `colima start` in the shell instead).
    @discardableResult
    func startEngine() -> Bool {
        guard let runtime = installedRuntime else { return false }
        isStarting = true
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: runtime.path), configuration: config) { _, _ in }
        // Give it up to a minute to come up; status polling clears the flag sooner.
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.isStarting = false }
        return true
    }

    // MARK: Lab cleanup

    /// Everything named with the lessons' `dz-` prefix.
    struct LabResources {
        var containers: [String] = []
        var images: [String] = []
        var volumes: [String] = []
        var networks: [String] = []
        var isEmpty: Bool { containers.isEmpty && images.isEmpty && volumes.isEmpty && networks.isEmpty }
        var summary: String {
            [("container", containers.count), ("image", images.count), ("volume", volumes.count), ("network", networks.count)]
                .filter { $0.1 > 0 }
                .map { "\($0.1) \($0.0)\($0.1 == 1 ? "" : "s")" }
                .joined(separator: ", ")
        }
    }

    var labResources: LabResources {
        guard let state else { return LabResources() }
        let p = Curriculum.prefix
        return LabResources(
            containers: state.containers.map(\.name).filter { $0.hasPrefix(p) },
            images: state.images.map(\.reference).filter { ref in
                let repo = ref.split(separator: "/").last.map(String.init) ?? ref
                return repo.hasPrefix(p)
            },
            volumes: state.volumes.filter { $0.hasPrefix(p) },
            networks: state.networks.filter { $0.hasPrefix(p) }
        )
    }

    /// Removes every `dz-` container, image, volume and network. Containers go
    /// first so their volumes and networks are free to delete.
    func removeLabResources(completion: @escaping @MainActor (String?) -> Void) {
        let lab = labResources
        let probe = probe
        Task.detached(priority: .userInitiated) {
            var failures: [String] = []
            func run(_ args: [String]) {
                guard let out = probe.run(args, timeout: 60) else { failures.append("docker \(args.first ?? "") timed out"); return }
                if out.status != 0 { failures.append(out.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }
            }
            if !lab.containers.isEmpty { run(["rm", "-f", "-v"] + lab.containers) }
            if !lab.volumes.isEmpty { run(["volume", "rm", "-f"] + lab.volumes) }
            if !lab.networks.isEmpty { run(["network", "rm"] + lab.networks) }
            if !lab.images.isEmpty { run(["rmi", "-f"] + lab.images) }
            let message = failures.isEmpty ? nil : failures.joined(separator: "\n")
            await MainActor.run {
                self.refresh()
                completion(message)
            }
        }
    }
}
