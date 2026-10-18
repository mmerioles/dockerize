import AppKit
import SwiftTerm
import DockerizeCore

/// Owns the embedded terminal view and the bash process running inside it,
/// where the learner runs `docker` for real.
@MainActor
final class TerminalController: NSObject, ObservableObject, LocalProcessTerminalViewDelegate {
    let view: LocalProcessTerminalView
    @Published private(set) var isRunning = false
    @Published private(set) var title = "bash"

    private let workspace: Workspace

    init(workspace: Workspace) {
        self.workspace = workspace
        self.view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        super.init()
        view.processDelegate = self
        configureAppearance()
    }

    private func configureAppearance() {
        view.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.nativeBackgroundColor = NSColor(hex: 0x0E0F12)
        view.nativeForegroundColor = NSColor(hex: 0xDEDFE3)
        view.caretColor = NSColor(hex: 0x2496ED)
        view.optionAsMetaKey = true
    }

    /// A restart waiting for the old shell to exit.
    private var pendingStart: URL?

    /// Starts bash in `directory`. If a shell is running, it is stopped first
    /// and the new one starts once it has exited.
    func start(in directory: URL) {
        if isRunning {
            pendingStart = directory
            view.terminate()
            return
        }
        launch(in: directory)
    }

    private func launch(in directory: URL) {
        view.feed(text: "\u{1b}c")   // full reset (RIS) so the old session's text is gone
        view.startProcess(
            executable: "/bin/bash",
            args: workspace.shellArguments,
            environment: workspace.environment(startIn: directory),
            execName: "bash",   // not "-bash": a login shell would skip --rcfile
            currentDirectory: directory.path
        )
        isRunning = true
        focus()
    }

    /// Moves the shell to a lesson folder. The leading space keeps the command
    /// out of history (HISTCONTROL=ignorespace), so it never counts as the
    /// learner's own work. Ctrl+U first clears anything half-typed.
    func changeDirectory(to directory: URL) {
        guard isRunning else { return start(in: directory) }
        view.send(txt: "\u{15} cd \(Self.quote(directory.path)) && clear\r")
        focus()
    }

    /// Types text at the prompt without pressing Enter, so the learner can read
    /// it, edit it and run it themselves.
    func type(_ text: String) {
        guard isRunning else { return }
        view.send(txt: "\u{15}" + text)
        focus()
    }

    /// Runs a command for the learner. The leading space keeps it out of
    /// history, so it never counts as their work.
    func run(_ command: String) {
        guard isRunning else { return }
        view.send(txt: "\u{15} " + command + "\r")
        focus()
    }

    func focus() {
        DispatchQueue.main.async { [view] in
            view.window?.makeFirstResponder(view)
        }
    }

    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: LocalProcessTerminalViewDelegate

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        Task { @MainActor in self.title = title }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in
            self.isRunning = false
            if let dir = self.pendingStart {
                self.pendingStart = nil
                self.launch(in: dir)
            }
        }
    }
}
