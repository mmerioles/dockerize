import Foundation

/// Decides whether a mission's check is satisfied, given the lesson workspace
/// on disk, the commands typed while the lesson was open, and a snapshot of
/// the Docker engine (nil when it isn't reachable).
public struct MissionEvaluator {
    public let workspace: URL
    public let commands: [CommandRecord]
    public let docker: DockerState?
    private let fm = FileManager.default

    public init(workspace: URL, commands: [CommandRecord], docker: DockerState? = nil) {
        self.workspace = workspace
        self.commands = commands
        self.docker = docker
    }

    public func isSatisfied(_ check: Check) -> Bool {
        switch check {
        case .ran(let pattern):
            return commands.contains { Self.matches($0.command, pattern) }
        case .ranOK(let pattern):
            return commands.contains { $0.status == 0 && Self.matches($0.command, pattern) }
        case .ranIn(let pattern, let suffix):
            return commands.contains {
                Self.matches($0.command, pattern) && ($0.directory + "/").hasSuffix("/" + suffix + "/")
            }
        case .exists(let path, let kind):
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url(path).path, isDirectory: &isDir) else { return false }
            switch kind {
            case .any: return true
            case .file: return !isDir.boolValue
            case .directory: return isDir.boolValue
            }
        case .missing(let path):
            // Check the link itself too, so a dangling symlink still counts as present.
            return !fm.fileExists(atPath: url(path).path)
                && (try? fm.destinationOfSymbolicLink(atPath: url(path).path)) == nil
        case .contains(let path, let text):
            return read(path)?.contains(text) ?? false
        case .matches(let path, let pattern):
            guard let text = read(path) else { return false }
            return Self.matches(text, pattern)
        case .container(let name, let state):
            guard let c = docker?.container(name) else { return false }
            switch state {
            case .exists: return true
            case .running: return c.isRunning
            case .stopped: return !c.isRunning
            }
        case .image(let reference):
            return docker?.hasImage(reference) ?? false
        case .volume(let name):
            return docker?.volumes.contains(name) ?? false
        case .network(let name):
            return docker?.networks.contains(name) ?? false
        case .onNetwork(let name, let network):
            return docker?.container(name)?.networks.contains(network) ?? false
        case .publishes(let name, let port):
            guard let c = docker?.container(name), c.isRunning else { return false }
            return c.publishedPorts.contains(port)
        case .mounts(let name, let text):
            return docker?.container(name)?.mounts.contains { $0.contains(text) } ?? false
        case .labeled(let key, let value):
            return docker?.containers.contains { $0.labels[key] == value } ?? false
        case .composeService(let project, let service):
            return docker?.containers.contains {
                $0.isRunning
                    && $0.labels["com.docker.compose.project"] == project
                    && $0.labels["com.docker.compose.service"] == service
            } ?? false
        case .all(let checks):
            return checks.allSatisfy(isSatisfied)
        case .any(let checks):
            return checks.contains(where: isSatisfied)
        case .not(let inner):
            return !isSatisfied(inner)
        }
    }

    private func url(_ path: String) -> URL {
        workspace.appendingPathComponent(path)
    }

    private func read(_ path: String) -> String? {
        try? String(contentsOf: url(path), encoding: .utf8)
    }

    static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
