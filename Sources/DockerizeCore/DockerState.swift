import Foundation

/// A snapshot of what the Docker engine has: containers, images, volumes and
/// networks. Mission checks read this instead of calling `docker` themselves.
public struct DockerState: Hashable, Sendable {
    public struct Container: Hashable, Sendable {
        public let name: String
        public let image: String
        /// "running", "exited", "created", "paused", "restarting" or "dead".
        public let state: String
        public let status: String
        public let ports: String
        public let networks: [String]
        public let mounts: [String]
        public let labels: [String: String]

        public init(name: String, image: String, state: String, status: String = "", ports: String = "",
                    networks: [String] = [], mounts: [String] = [], labels: [String: String] = [:]) {
            self.name = name
            self.image = image
            self.state = state
            self.status = status
            self.ports = ports
            self.networks = networks
            self.mounts = mounts
            self.labels = labels
        }

        public var isRunning: Bool { state == "running" }

        /// Host ports from a `docker ps` ports column like
        /// `0.0.0.0:8080->80/tcp, [::]:8080->80/tcp`.
        public var publishedPorts: Set<Int> {
            var result: Set<Int> = []
            for part in ports.split(separator: ",") {
                guard let arrow = part.range(of: "->") else { continue }
                let host = part[part.startIndex..<arrow.lowerBound]
                guard let colon = host.lastIndex(of: ":") else { continue }
                let number = host[host.index(after: colon)...].split(separator: "-").first ?? ""
                if let port = Int(number) { result.insert(port) }
            }
            return result
        }
    }

    public struct Image: Hashable, Sendable {
        public let repository: String
        public let tag: String
        public let id: String
        public let size: String

        public init(repository: String, tag: String, id: String = "", size: String = "") {
            self.repository = repository
            self.tag = tag
            self.id = id
            self.size = size
        }

        public var reference: String { "\(repository):\(tag)" }
    }

    public var containers: [Container]
    public var images: [Image]
    public var volumes: [String]
    public var networks: [String]

    public init(containers: [Container] = [], images: [Image] = [], volumes: [String] = [], networks: [String] = []) {
        self.containers = containers
        self.images = images
        self.volumes = volumes
        self.networks = networks
    }

    public func container(_ name: String) -> Container? {
        containers.first { $0.name == name }
    }

    /// Whether an image exists. `nginx` means `nginx:latest`, and Docker Hub
    /// prefixes (`docker.io/library/`) are ignored.
    public func hasImage(_ reference: String) -> Bool {
        let wanted = Self.normalize(reference)
        return images.contains { Self.normalize($0.reference) == wanted }
    }

    static func normalize(_ reference: String) -> String {
        var ref = reference
        for prefix in ["docker.io/library/", "docker.io/", "index.docker.io/library/"] where ref.hasPrefix(prefix) {
            ref = String(ref.dropFirst(prefix.count))
        }
        // A colon after the last slash is a tag; one before it is a registry port.
        let lastSlash = ref.lastIndex(of: "/") ?? ref.startIndex
        if ref[lastSlash...].contains(":") == false { ref += ":latest" }
        return ref
    }

    // MARK: Parsing `docker … --format '{{json .}}'` output

    /// Parses `docker ps -a --no-trunc --format '{{json .}}'`, one JSON object per line.
    public static func parseContainers(_ output: String) -> [Container] {
        jsonLines(output).compactMap { obj in
            guard let names = obj["Names"] as? String else { return nil }
            return Container(
                name: names.split(separator: ",").first.map(String.init) ?? names,
                image: obj["Image"] as? String ?? "",
                state: (obj["State"] as? String ?? "").lowercased(),
                status: obj["Status"] as? String ?? "",
                ports: obj["Ports"] as? String ?? "",
                networks: list(obj["Networks"]),
                mounts: list(obj["Mounts"]),
                labels: labels(obj["Labels"] as? String ?? "")
            )
        }
    }

    /// Parses `docker images --format '{{json .}}'`.
    public static func parseImages(_ output: String) -> [Image] {
        jsonLines(output).compactMap { obj in
            guard let repo = obj["Repository"] as? String, repo != "<none>" else { return nil }
            return Image(
                repository: repo,
                tag: obj["Tag"] as? String ?? "latest",
                id: obj["ID"] as? String ?? "",
                size: obj["Size"] as? String ?? ""
            )
        }
    }

    /// Parses one name per line (`docker volume ls --format '{{.Name}}'`).
    public static func parseNames(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func jsonLines(_ output: String) -> [[String: Any]] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    }

    private static func list(_ value: Any?) -> [String] {
        guard let s = value as? String else { return [] }
        return s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Labels come as `key=value,key2=value2`. Values can contain commas, so a
    /// piece without `=` is glued back onto the previous value.
    static func labels(_ s: String) -> [String: String] {
        var result: [String: String] = [:]
        var lastKey: String?
        for piece in s.split(separator: ",", omittingEmptySubsequences: false) {
            if let eq = piece.firstIndex(of: "=") {
                let key = String(piece[..<eq])
                result[key] = String(piece[piece.index(after: eq)...])
                lastKey = key
            } else if let key = lastKey {
                result[key, default: ""] += "," + piece
            }
        }
        return result
    }
}

/// Runs the `docker` CLI to read the engine's state. Blocking: call it off the main thread.
public struct DockerProbe: Sendable {
    public let executable: String?
    public let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        var env = environment
        env["PATH"] = Workspace.searchPath(env["PATH"])
        self.environment = env
        self.executable = Self.locate(in: env["PATH"] ?? "")
    }

    public var isInstalled: Bool { executable != nil }

    /// The engine's server version, or nil if the daemon isn't reachable.
    public func serverVersion() -> String? {
        let out = run(["version", "--format", "{{.Server.Version}}"], timeout: 4)
        guard let out, out.status == 0 else { return nil }
        let v = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    public func clientVersion() -> String? {
        guard let out = run(["version", "--format", "{{.Client.Version}}"], timeout: 4) else { return nil }
        let v = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    /// Reads containers, images, volumes and networks. Nil if the engine isn't reachable.
    public func snapshot() -> DockerState? {
        guard let ps = run(["ps", "-a", "--no-trunc", "--format", "{{json .}}"]), ps.status == 0 else { return nil }
        let images = run(["images", "--format", "{{json .}}"])?.stdout ?? ""
        let volumes = run(["volume", "ls", "--format", "{{.Name}}"])?.stdout ?? ""
        let networks = run(["network", "ls", "--format", "{{.Name}}"])?.stdout ?? ""
        return DockerState(
            containers: DockerState.parseContainers(ps.stdout),
            images: DockerState.parseImages(images),
            volumes: DockerState.parseNames(volumes),
            networks: DockerState.parseNames(networks)
        )
    }

    public struct Output: Sendable {
        public let status: Int32
        public let stdout: String
        public let stderr: String
    }

    @discardableResult
    public func run(_ args: [String], timeout: TimeInterval = 10) -> Output? {
        guard let executable else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = args
        p.environment = environment
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return nil }

        // Read both pipes while the process runs so a full pipe can't block it.
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter()
        DispatchQueue.global().async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        if group.wait(timeout: .now() + timeout) == .timedOut {
            p.terminate()
            return nil
        }
        p.waitUntilExit()
        return Output(
            status: p.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }

    static func locate(in path: String) -> String? {
        for dir in path.split(separator: ":") {
            let candidate = "\(dir)/docker"
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}
