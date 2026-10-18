import XCTest
@testable import DockerizeCore

final class CurriculumTests: XCTestCase {
    func testIdsAreUnique() {
        let ids = Curriculum.lessons.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate lesson ids")
        let cats = Curriculum.categories.map(\.id)
        XCTAssertEqual(cats.count, Set(cats).count, "duplicate category ids")
    }

    func testEveryLessonHasContent() {
        for lesson in Curriculum.lessons {
            XCTAssertFalse(lesson.sections.isEmpty, lesson.id)
            XCTAssertFalse(lesson.missions.isEmpty, lesson.id)
            XCTAssertFalse(lesson.reference.isEmpty, lesson.id)
        }
    }

    func testDiagramsAreWellFormed() {
        for lesson in Curriculum.lessons {
            let d = lesson.diagram
            let ids = Set(d.nodes.map(\.id))
            XCTAssertEqual(ids.count, d.nodes.count, "\(lesson.id): duplicate node ids")
            let cells = d.nodes.map { "\($0.col),\($0.row)" }
            XCTAssertEqual(cells.count, Set(cells).count, "\(lesson.id): two nodes share a grid cell")
            XCTAssertLessThanOrEqual(d.columns, 5, "\(lesson.id): diagram too wide")
            XCTAssertLessThanOrEqual(d.rows, 3, "\(lesson.id): diagram too tall")
            for edge in d.edges {
                XCTAssertTrue(ids.contains(edge.from), "\(lesson.id): unknown edge source \(edge.from)")
                XCTAssertTrue(ids.contains(edge.to), "\(lesson.id): unknown edge target \(edge.to)")
            }
            for group in d.groups {
                for member in group.members {
                    XCTAssertTrue(ids.contains(member), "\(lesson.id): unknown group member \(member)")
                }
            }
        }
    }

    func testAllRegexesCompile() {
        for lesson in Curriculum.lessons {
            for mission in lesson.missions {
                for p in Self.patterns(mission.check) {
                    XCTAssertNoThrow(try NSRegularExpression(pattern: p), "\(lesson.id): bad regex \(p)")
                }
            }
        }
    }

    /// Everything a mission checks for must be named dz-… (so cleanup can find
    /// it), and no two lessons may check the same container, volume or network
    /// (so one lesson's leftovers can't complete another's missions).
    func testLabResourcesArePrefixedAndUnique() {
        let pulled = Set([Img.hello, Img.alpine, Img.busybox, Img.nginx, Img.redis, Img.python, Img.registry])
        var owner: [String: String] = [:]
        for lesson in Curriculum.lessons {
            var mine: Set<String> = []
            for mission in lesson.missions {
                for (kind, name) in Self.resources(mission.check) {
                    if kind == "image" && pulled.contains(name) { continue }
                    if kind == "compose" || kind == "label" { continue }
                    let base = name.split(separator: "/").last.map(String.init) ?? name
                    XCTAssertTrue(base.hasPrefix(Curriculum.prefix), "\(lesson.id): \(kind) '\(name)' isn't named dz-…")
                    if kind != "image" { mine.insert("\(kind):\(name)") }
                }
            }
            for key in mine {
                if let other = owner[key] {
                    XCTFail("\(key) is checked by both \(other) and \(lesson.id)")
                }
                owner[key] = lesson.id
            }
        }
    }

    func testLessonImagesArePinned() {
        let known = Set([Img.hello, Img.alpine, Img.busybox, Img.nginx, Img.redis, Img.python, Img.registry])
        for lesson in Curriculum.lessons {
            for image in lesson.images {
                XCTAssertTrue(known.contains(image), "\(lesson.id): \(image) isn't one of the Img tags")
            }
        }
    }

    static func patterns(_ check: Check) -> [String] {
        switch check {
        case .ran(let p), .ranOK(let p), .ranIn(let p, _), .matches(_, let p): return [p]
        case .all(let c), .any(let c): return c.flatMap(patterns)
        case .not(let c): return patterns(c)
        default: return []
        }
    }

    static func resources(_ check: Check) -> [(String, String)] {
        switch check {
        case .container(let n, _), .publishes(let n, _), .mounts(let n, _): return [("container", n)]
        case .onNetwork(let c, let n): return [("container", c), ("network", n)]
        case .image(let n): return [("image", n)]
        case .volume(let n): return [("volume", n)]
        case .network(let n): return [("network", n)]
        case .composeService(let p, _): return [("compose", p)]
        case .labeled(let k, _): return [("label", k)]
        case .all(let c), .any(let c): return c.flatMap(resources)
        case .not(let c): return resources(c)
        default: return []
        }
    }
}

final class DockerStateTests: XCTestCase {
    func testParsesContainers() {
        let line = #"{"Command":"\"/docker-entrypoint.…\"","CreatedAt":"2026-10-17","ID":"abc","Image":"nginx:1.27-alpine","Labels":"com.docker.compose.project=dz-shop,com.docker.compose.service=web,note=a,b","LocalVolumes":"0","Mounts":"dz-data,/Users/me/site","Names":"dz-web","Networks":"bridge,dz-net","Ports":"0.0.0.0:8080->80/tcp, [::]:8080->80/tcp, 127.0.0.1:8085->443/tcp","RunningFor":"1 minute ago","Size":"0B","State":"running","Status":"Up 1 minute"}"#
        let containers = DockerState.parseContainers(line + "\n" + "not json\n")
        XCTAssertEqual(containers.count, 1)
        let c = containers[0]
        XCTAssertEqual(c.name, "dz-web")
        XCTAssertTrue(c.isRunning)
        XCTAssertEqual(c.publishedPorts, [8080, 8085])
        XCTAssertEqual(c.networks, ["bridge", "dz-net"])
        XCTAssertEqual(c.mounts, ["dz-data", "/Users/me/site"])
        XCTAssertEqual(c.labels["com.docker.compose.service"], "web")
        XCTAssertEqual(c.labels["note"], "a,b", "commas inside a label value are kept")
    }

    func testParsesImagesAndNormalizesReferences() {
        let out = """
        {"Containers":"N/A","ID":"sha256:1","Repository":"alpine","Size":"8MB","Tag":"3.20"}
        {"ID":"sha256:2","Repository":"localhost:5001/dz-app","Size":"9MB","Tag":"1.0"}
        {"ID":"sha256:3","Repository":"<none>","Size":"9MB","Tag":"<none>"}
        {"ID":"sha256:4","Repository":"hello-world","Size":"9kB","Tag":"latest"}
        """
        let state = DockerState(images: DockerState.parseImages(out))
        XCTAssertEqual(state.images.count, 3)
        XCTAssertTrue(state.hasImage("alpine:3.20"))
        XCTAssertTrue(state.hasImage("docker.io/library/alpine:3.20"))
        XCTAssertFalse(state.hasImage("alpine"), "alpine means alpine:latest")
        XCTAssertTrue(state.hasImage("hello-world"))
        XCTAssertTrue(state.hasImage("localhost:5001/dz-app:1.0"))
        XCTAssertFalse(state.hasImage("localhost:5001/dz-app"))
    }

    func testDockerChecks() {
        let state = DockerState(
            containers: [
                .init(name: "dz-web", image: "nginx", state: "running", ports: "0.0.0.0:8080->80/tcp",
                      networks: ["dz-net"], mounts: ["dz-data"],
                      labels: ["com.docker.compose.project": "dz-shop", "com.docker.compose.service": "web"]),
                .init(name: "dz-old", image: "alpine", state: "exited"),
            ],
            images: [.init(repository: "dz-app", tag: "1.0")],
            volumes: ["dz-data"],
            networks: ["bridge", "dz-net"]
        )
        let eval = MissionEvaluator(workspace: URL(fileURLWithPath: "/tmp"), commands: [], docker: state)
        XCTAssertTrue(eval.isSatisfied(.container("dz-web", .running)))
        XCTAssertFalse(eval.isSatisfied(.container("dz-web", .stopped)))
        XCTAssertTrue(eval.isSatisfied(.container("dz-old", .stopped)))
        XCTAssertTrue(eval.isSatisfied(.container("dz-old", .exists)))
        XCTAssertFalse(eval.isSatisfied(.container("dz-nope", .exists)))
        XCTAssertTrue(eval.isSatisfied(.image("dz-app:1.0")))
        XCTAssertTrue(eval.isSatisfied(.volume("dz-data")))
        XCTAssertTrue(eval.isSatisfied(.network("dz-net")))
        XCTAssertTrue(eval.isSatisfied(.onNetwork("dz-web", "dz-net")))
        XCTAssertTrue(eval.isSatisfied(.publishes("dz-web", 8080)))
        XCTAssertFalse(eval.isSatisfied(.publishes("dz-web", 80)))
        XCTAssertTrue(eval.isSatisfied(.mounts("dz-web", "dz-data")))
        XCTAssertTrue(eval.isSatisfied(.composeService("dz-shop", "web")))
        XCTAssertTrue(eval.isSatisfied(.labeled("com.docker.compose.project", "dz-shop")))

        // With the engine unreachable, Docker checks are never satisfied.
        let offline = MissionEvaluator(workspace: URL(fileURLWithPath: "/tmp"), commands: [], docker: nil)
        XCTAssertFalse(offline.isSatisfied(.container("dz-web", .exists)))
        XCTAssertTrue(offline.isSatisfied(.not(.container("dz-web", .exists))))
    }
}

final class WorkspaceTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("dockerize-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testCommandRecordParsing() {
        let r = CommandRecord(logLine: "1\t/tmp/x\tdocker run\t--rm alpine")
        XCTAssertEqual(r?.status, 1)
        XCTAssertEqual(r?.directory, "/tmp/x")
        XCTAssertEqual(r?.command, "docker run\t--rm alpine")
        XCTAssertNil(CommandRecord(logLine: "garbage"))
    }

    /// No mission should already be complete in a freshly seeded workspace on
    /// an empty engine.
    func testFreshWorkspaceCompletesNothing() throws {
        let ws = Workspace(root: root)
        try ws.prepare()
        for lesson in Curriculum.lessons {
            let dir = try ws.ensure(lesson)
            let eval = MissionEvaluator(workspace: dir, commands: [], docker: DockerState())
            for mission in lesson.missions {
                XCTAssertFalse(eval.isSatisfied(mission.check), "\(lesson.id): '\(mission.title)' is done before starting")
            }
        }
    }

    func testResetRestoresSeed() throws {
        let ws = Workspace(root: root)
        try ws.prepare()
        let lesson = try XCTUnwrap(Curriculum.lessons.first { !$0.seed.files.isEmpty })
        let file = lesson.seed.files[0].path
        let dir = try ws.ensure(lesson)
        try FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        try ws.reset(lesson)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent(file).path))
    }

    /// Runs the generated profile in a real interactive bash and checks that
    /// commands get logged, with their exit status, and space-prefixed ones don't.
    func testProfileLogsCommands() throws {
        let ws = Workspace(root: root)
        try ws.prepare()
        let lesson = Curriculum.lessons[0]
        let dir = try ws.ensure(lesson)

        let input = "echo hi\n cd /tmp\nfalse\n\nls -la\nexit\n"
        _ = try Shell.run(args: ws.shellArguments, env: ws.environment(startIn: dir), stdin: input, cwd: dir)

        let records = ws.readNewCommands()
        XCTAssertEqual(records.map(\.command), ["echo hi", "false", "ls -la"])
        XCTAssertEqual(records.map(\.status), [0, 1, 0])
        XCTAssertTrue(records[0].directory.hasSuffix("/\(lesson.id)"))
        XCTAssertTrue(ws.readNewCommands().isEmpty, "log lines are consumed once")
    }

    func testEnvironmentPointsDockerAtRealConfig() throws {
        let ws = Workspace(root: root)
        let env = ws.environment(startIn: root)
        XCTAssertTrue(env.contains("HOME=\(ws.home.path)"))
        XCTAssertTrue(env.contains { $0.hasPrefix("DOCKER_CONFIG=") && !$0.contains(ws.home.path) })
    }
}

/// Runs every mission's model solution against a real Docker engine and checks
/// each mission is then complete. Slow and needs network for pulls, so it only
/// runs with DOCKERIZE_E2E=1:
///
///     DOCKERIZE_E2E=1 swift test --filter SolutionTests
///
/// Optionally DOCKERIZE_LESSON=<id> runs one lesson. It removes dz-… resources
/// before and after.
final class SolutionTests: XCTestCase {
    func testSolutionsCompleteEveryMission() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["DOCKERIZE_E2E"] == "1" else { throw XCTSkip("set DOCKERIZE_E2E=1 to run against a real engine") }
        let probe = DockerProbe()
        guard probe.serverVersion() != nil else { throw XCTSkip("Docker engine isn't reachable") }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dockerize-e2e-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let ws = Workspace(root: root)
        try ws.prepare()

        let lessons = env["DOCKERIZE_LESSON"].flatMap { id in Curriculum.lesson(id).map { [$0] } } ?? Curriculum.lessons
        Self.cleanLab(probe)
        defer { Self.cleanLab(probe) }

        for lesson in lessons {
            let dir = try ws.ensure(lesson)
            var shellEnv = ws.environment(startIn: dir)
            shellEnv += ["PAGER=cat", "MANPAGER=cat"]
            var records: [CommandRecord] = []
            for mission in lesson.missions {
                // There's no TTY here, so interactive runs become plain -i.
                let solution = mission.solution
                    .replacingOccurrences(of: " -it ", with: " -i ")
                    .replacingOccurrences(of: " -ti ", with: " -i ")
                let commands = solution.contains("<<") ? [solution] : solution.split(separator: "\n").map(String.init)
                for command in commands {
                    let script = "cd \"\(dir.path)\"\n\(command)\nprintf '\\n__STATUS__%s\\t%s' \"$?\" \"$PWD\""
                    let out = try Shell.run(args: ["-c", script], env: shellEnv, stdin: "", cwd: dir, timeout: 300)
                    var status: Int32 = -1
                    var pwd = dir.path
                    if let marker = out.range(of: "__STATUS__", options: .backwards) {
                        let parts = out[marker.upperBound...].split(separator: "\t", maxSplits: 1)
                        status = Int32(parts.first ?? "") ?? -1
                        if parts.count > 1 { pwd = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                    records.append(CommandRecord(status: status, directory: pwd, command: mission.solution.contains("<<") ? command : command))
                    if status != 0 { print("[\(lesson.id)] exit \(status): \(command)\n\(out.suffix(600))") }
                }
                let eval = MissionEvaluator(workspace: dir, commands: records, docker: probe.snapshot())
                XCTAssertTrue(eval.isSatisfied(mission.check), "\(lesson.id): solution for '\(mission.title)' doesn't satisfy its check")
            }
        }
    }

    /// Removes every dz-… container, volume, network and image.
    static func cleanLab(_ probe: DockerProbe) {
        guard let state = probe.snapshot() else { return }
        let p = Curriculum.prefix
        let containers = state.containers.map(\.name).filter { $0.hasPrefix(p) }
        if !containers.isEmpty { probe.run(["rm", "-f", "-v"] + containers, timeout: 120) }
        let volumes = state.volumes.filter { $0.hasPrefix(p) }
        if !volumes.isEmpty { probe.run(["volume", "rm", "-f"] + volumes) }
        let networks = state.networks.filter { $0.hasPrefix(p) }
        if !networks.isEmpty { probe.run(["network", "rm"] + networks) }
        let images = state.images.map(\.reference).filter { ($0.split(separator: "/").last.map(String.init) ?? $0).hasPrefix(p) }
        if !images.isEmpty { probe.run(["rmi", "-f"] + images, timeout: 120) }
    }
}

enum Shell {
    @discardableResult
    static func run(args: [String], env: [String], stdin: String, cwd: URL, timeout: TimeInterval = 60) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = args
        p.currentDirectoryURL = cwd
        var dict: [String: String] = [:]
        for kv in env {
            let parts = kv.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { dict[String(parts[0])] = String(parts[1]) }
        }
        p.environment = dict
        let inPipe = Pipe(), outPipe = Pipe()
        p.standardInput = inPipe
        p.standardOutput = outPipe
        p.standardError = outPipe
        try p.run()
        inPipe.fileHandleForWriting.write(stdin.data(using: .utf8)!)
        try inPipe.fileHandleForWriting.close()
        var data = Data()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            data = outPipe.fileHandleForReading.readDataToEndOfFile()
            done.signal()
        }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            p.terminate()
            done.wait()
        }
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
