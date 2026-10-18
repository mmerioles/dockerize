import AppKit
import SwiftUI
import DockerizeCore

enum Screen: Hashable {
    case dashboard
    case roadmap
    case engine
    case cheatSheet
    case lesson(String)
}

/// App state: which screen is showing, mission progress, and the loop that
/// checks missions as the learner types and as the Docker engine changes.
@MainActor
final class AppModel: ObservableObject {
    @Published var screen: Screen = .dashboard
    @Published private(set) var completed: Set<String>
    /// The mission that was just completed, for the success flash.
    @Published private(set) var justCompleted: String?
    @Published var setupError: String?
    /// Whether the lessons sidebar is folded down to its icon rail.
    @Published var sidebarCollapsed: Bool {
        didSet { defaults.set(sidebarCollapsed, forKey: Self.sidebarKey) }
    }

    let workspace: Workspace
    let terminal: TerminalController
    let engine = EngineMonitor()
    let bashVersion: String

    /// Commands typed while each lesson was open, keyed by lesson id.
    private var commands: [String: [CommandRecord]] = [:]
    private var timer: Timer?
    private var ticks = 0
    private let defaults: UserDefaults
    private static let completedKey = "dockerize.completed"
    private static let lastLessonKey = "dockerize.lastLesson"
    private static let sidebarKey = "dockerize.sidebarCollapsed"

    init() {
        if Screenshots.isActive {
            // Demo run: a throwaway workspace and settings, so real progress is never touched.
            workspace = Workspace(root: Screenshots.workspaceRoot)
            defaults = UserDefaults(suiteName: Screenshots.defaultsSuite) ?? .standard
            defaults.removePersistentDomain(forName: Screenshots.defaultsSuite)
            defaults.set(Array(Screenshots.demoCompleted), forKey: Self.completedKey)
        } else {
            workspace = Workspace()
            defaults = .standard
        }
        completed = Set(defaults.stringArray(forKey: Self.completedKey) ?? [])
        sidebarCollapsed = defaults.bool(forKey: Self.sidebarKey)
        terminal = TerminalController(workspace: workspace)
        bashVersion = Self.readBashVersion()
        do {
            try workspace.prepare()
        } catch {
            setupError = "Couldn't create the workspace at \(workspace.root.path): \(error.localizedDescription)"
        }
        if let id = defaults.string(forKey: Self.lastLessonKey), Curriculum.lesson(id) != nil {
            screen = .lesson(id)
        }
    }

    // MARK: Lifecycle

    func startShell() {
        let dir = currentLesson.flatMap { try? workspace.ensure($0) } ?? workspace.home
        terminal.start(in: dir)
        timer?.invalidate()
        engine.refresh()   // read-only, so the screenshot run does it too
        guard !Screenshots.isActive else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Every 0.6s: read new commands. Every few seconds: re-read the engine,
    /// more often when something on screen depends on it.
    private func tick() {
        ticks += 1
        poll()
        let watching = screen == .engine
            || (currentLesson.map { $0.usesDockerState && !isComplete($0) } ?? false)
            || !engine.status.isRunning && engine.isStarting
        let every = watching ? 4 : 17   // ~2.4s or ~10s
        if ticks % every == 0 { refreshEngine() }
    }

    func refreshEngine() {
        engine.refresh { [weak self] in
            guard let self, let lesson = self.currentLesson else { return }
            self.evaluate(lesson)
        }
    }

    func restartShell() {
        let dir = currentLesson.map { workspace.directory(for: $0) } ?? workspace.home
        terminal.start(in: dir)
    }

    // MARK: Navigation

    var currentLesson: Lesson? {
        if case .lesson(let id) = screen { return Curriculum.lesson(id) }
        return nil
    }

    func open(_ lesson: Lesson) {
        // Credit anything typed so far to the lesson that was open while it was typed.
        poll()
        screen = .lesson(lesson.id)
        defaults.set(lesson.id, forKey: Self.lastLessonKey)
        do {
            let dir = try workspace.ensure(lesson)
            terminal.changeDirectory(to: dir)
        } catch {
            setupError = "Couldn't prepare the workspace for \(lesson.title): \(error.localizedDescription)"
        }
    }

    func openDashboard() {
        poll()
        screen = .dashboard
    }

    func openRoadmap() {
        poll()
        screen = .roadmap
    }

    func openEngine() {
        poll()
        screen = .engine
        refreshEngine()
    }

    func openCheatSheet() {
        poll()
        screen = .cheatSheet
    }

    // MARK: Docker

    /// Pulls the lesson's images in the shell, so the learner sees progress.
    /// The leading space keeps it out of history, so it never completes a mission.
    func pullImages(_ images: [String]) {
        guard !images.isEmpty else { return }
        let cmd = images.map { "docker pull \($0)" }.joined(separator: " && ")
        terminal.run(cmd)
    }

    func missingImages(_ lesson: Lesson) -> [String] {
        guard let state = engine.state else { return lesson.images }
        return lesson.images.filter { !state.hasImage($0) }
    }

    /// Opens OrbStack / Docker Desktop / Rancher Desktop, or types
    /// `colima start` when only Colima is installed.
    func startEngine() {
        if !engine.startEngine() {
            terminal.type("colima start")
        }
    }

    func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) { sidebarCollapsed.toggle() }
    }

    func goNext() {
        if let lesson = currentLesson, let next = Curriculum.next(after: lesson) { open(next) }
        else if currentLesson == nil, let first = Curriculum.lessons.first { open(first) }
    }

    func goPrevious() {
        if let lesson = currentLesson, let prev = Curriculum.previous(before: lesson) { open(prev) }
    }

    /// The first lesson that still has unfinished missions.
    var continueLesson: Lesson {
        Curriculum.lessons.first { !isComplete($0) } ?? Curriculum.lessons[0]
    }

    // MARK: Progress

    static func key(_ lesson: Lesson, _ index: Int) -> String { "\(lesson.id)#\(index)" }

    func isDone(_ lesson: Lesson, _ index: Int) -> Bool {
        completed.contains(Self.key(lesson, index))
    }

    func doneCount(_ lesson: Lesson) -> Int {
        lesson.missions.indices.filter { isDone(lesson, $0) }.count
    }

    func isComplete(_ lesson: Lesson) -> Bool {
        doneCount(lesson) == lesson.missions.count
    }

    func progress(_ category: DockerizeCore.Category) -> (done: Int, total: Int) {
        let done = category.lessons.reduce(0) { $0 + doneCount($1) }
        let total = category.lessons.reduce(0) { $0 + $1.missions.count }
        return (done, total)
    }

    var overallProgress: (done: Int, total: Int) {
        let total = Curriculum.lessons.reduce(0) { $0 + $1.missions.count }
        return (completed.count, total)
    }

    /// Deletes the lesson's files, seeds it again, and clears its missions.
    func resetCurrentLesson() {
        guard let lesson = currentLesson else { return }
        do {
            try workspace.reset(lesson)
        } catch {
            setupError = "Couldn't reset \(lesson.title): \(error.localizedDescription)"
            return
        }
        commands[lesson.id] = []
        for i in lesson.missions.indices { completed.remove(Self.key(lesson, i)) }
        save()
        terminal.changeDirectory(to: workspace.directory(for: lesson))
    }

    func resetAllProgress() {
        completed.removeAll()
        commands.removeAll()
        save()
    }

    func revealInFinder() {
        let url = currentLesson.map { workspace.directory(for: $0) } ?? workspace.home
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: Mission checking

    private func poll() {
        guard !Screenshots.isActive else { return }
        let new = workspace.readNewCommands()
        // A docker command probably changed the engine; look again right away.
        if new.contains(where: { $0.command.contains("docker") || $0.command.contains("colima") }) {
            refreshEngine()
        }
        guard let lesson = currentLesson else { return }
        if !new.isEmpty { commands[lesson.id, default: []] += new }
        evaluate(lesson)
    }

    private func evaluate(_ lesson: Lesson) {
        let evaluator = MissionEvaluator(
            workspace: workspace.directory(for: lesson),
            commands: commands[lesson.id] ?? [],
            docker: engine.state
        )
        var newlyDone: [String] = []
        for (i, mission) in lesson.missions.enumerated() where !isDone(lesson, i) {
            if evaluator.isSatisfied(mission.check) {
                newlyDone.append(Self.key(lesson, i))
            }
        }
        guard !newlyDone.isEmpty else { return }
        completed.formUnion(newlyDone)
        save()
        NSSound(named: isComplete(lesson) ? "Glass" : "Pop")?.play()
        withAnimation(.spring(duration: 0.35)) { justCompleted = newlyDone.last }
        let flashed = newlyDone.last
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self, self.justCompleted == flashed else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.justCompleted = nil }
        }
    }

    private func save() {
        defaults.set(Array(completed).sorted(), forKey: Self.completedKey)
    }

    private static func readBashVersion() -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", "echo $BASH_VERSION"]
        let pipe = Pipe()
        p.standardOutput = pipe
        guard (try? p.run()) != nil else { return "unknown" }
        p.waitUntilExit()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
