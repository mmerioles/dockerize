import AppKit
import SwiftUI
import DockerizeCore

/// `Dockerize --screenshots DIR` renders the app in a few demo states to PNGs
/// (used by the website in docs/) and quits. It runs against a throwaway
/// workspace with made-up progress, and the window is kept invisible.
enum Screenshots {
    static let outputDir: URL? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--screenshots"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1])
    }()

    static var isActive: Bool { outputDir != nil }

    static let workspaceRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("dockerize-screenshots-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
    static let defaultsSuite = "io.github.mmerioles.dockerize.screenshots"
    static let windowSize = CGSize(width: 1440, height: 900)

    /// Progress for the demo: the first two categories done, a few missions into the rest.
    @MainActor
    static var demoCompleted: Set<String> {
        var keys: Set<String> = []
        for category in Curriculum.categories.prefix(2) {
            for lesson in category.lessons {
                for i in lesson.missions.indices { keys.insert(AppModel.key(lesson, i)) }
            }
        }
        for (id, count) in [("pulling-images", 2), ("first-dockerfile", 3), ("volumes", 1), ("networks", 2), ("compose-basics", 1)] {
            guard let lesson = Curriculum.lesson(id) else { continue }
            for i in 0..<min(count, lesson.missions.count) { keys.insert(AppModel.key(lesson, i)) }
        }
        return keys
    }

    private struct Shot {
        let name: String
        let screen: Screen
        var collapsed = false
        var commands: [String] = []
    }

    private static let shots: [Shot] = [
        // Read-only commands only: the screenshot run talks to your real engine.
        Shot(name: "lesson", screen: .lesson("first-dockerfile"), commands: [
            "cat Dockerfile",
            "docker images",
        ]),
        Shot(name: "focus", screen: .lesson("networks"), collapsed: true, commands: [
            "docker network ls",
            "docker ps",
        ]),
        Shot(name: "dashboard", screen: .dashboard),
        Shot(name: "roadmap", screen: .roadmap),
        Shot(name: "engine", screen: .engine),
        Shot(name: "cheatsheet", screen: .cheatSheet),
    ]

    @MainActor
    static func run(_ model: AppModel) async {
        guard let dir = outputDir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? await Task.sleep(for: .milliseconds(300))
        guard let window = NSApp.windows.first(where: { $0.contentView != nil && $0.isVisible }) else {
            print("error: no window to capture")
            exit(1)
        }
        // Park the window behind every other app's windows so the run doesn't get in the way.
        window.setContentSize(windowSize)
        window.orderBack(nil)

        for shot in shots {
            model.sidebarCollapsed = shot.collapsed
            switch shot.screen {
            case .lesson(let id): if let lesson = Curriculum.lesson(id) { model.open(lesson) }
            case .dashboard: model.openDashboard()
            case .roadmap: model.openRoadmap()
            case .engine: model.openEngine()
            case .cheatSheet: model.openCheatSheet()
            }
            try? await Task.sleep(for: .milliseconds(900))
            for command in shot.commands {
                model.terminal.view.send(txt: command + "\r")
                // docker commands are slower than shell builtins; let each finish drawing.
                try? await Task.sleep(for: .milliseconds(1200))
            }
            try? await Task.sleep(for: .milliseconds(1500))
            // The terminal only repaints while its window is on screen, so bring
            // it forward for the capture and park it again afterwards.
            window.orderFrontRegardless()
            model.terminal.view.needsDisplay = true
            try? await Task.sleep(for: .milliseconds(400))
            save(window, to: dir.appendingPathComponent("\(shot.name).png"))
            window.orderBack(nil)
        }
        try? FileManager.default.removeItem(at: workspaceRoot)
        UserDefaults.standard.removePersistentDomain(forName: defaultsSuite)
        exit(0)
    }

    @MainActor
    private static func save(_ window: NSWindow, to url: URL) {
        // Ask the window server for this window's pixels. It works while the
        // window sits behind everything else, and includes the title bar.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l", String(window.windowNumber), url.path]
        do {
            try p.run()
            p.waitUntilExit()
            print(p.terminationStatus == 0 ? "wrote \(url.path)" : "error: screencapture failed for \(url.lastPathComponent)")
        } catch {
            print("error: \(error.localizedDescription)")
        }
    }
}
