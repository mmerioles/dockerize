import SwiftUI
import SwiftTerm
import DockerizeCore

/// Right-hand column: the live shell, filling the full height. On a lesson the
/// missions live in the lesson header instead (see `MissionStrip`).
struct WorkbenchPanel: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            if model.currentLesson == nil {
                WelcomeShellCard()
            }
            TerminalCard()
        }
        .padding(12)
        .background(Color(hex: 0xF1F2F3))
    }
}

/// Compact missions bar: shows only the mission you're on. Hints, the
/// solution, and the full list stay folded away until asked for.
struct MissionStrip: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    /// A mission picked from the list; otherwise the first one not done.
    @State private var picked: Int?
    @State private var showHint = false
    @State private var showSolution = false
    @State private var showList = false
    @State private var confirmReset = false

    private var total: Int { lesson.missions.count }
    private var firstOpen: Int? { lesson.missions.indices.first { !model.isDone(lesson, $0) } }
    private var current: Int? {
        if let picked, !model.isDone(lesson, picked) { return picked }
        return firstOpen
    }
    private var flashing: Bool {
        model.justCompleted.map { $0.hasPrefix(lesson.id + "#") } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let index = current { currentMission(index) } else { completeRow }
                Spacer(minLength: 6)
                trailingControls
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            segments
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            if let index = current, showHint || showSolution {
                details(index)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }

            if showList {
                Divider().overlay(Theme.border)
                list
            }
        }
        .background(flashing ? Theme.successSurface : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(flashing ? Theme.successBorder : Theme.border))
        .animation(.easeOut(duration: 0.18), value: showList)
        .animation(.easeOut(duration: 0.18), value: flashing)
        .confirmationDialog("Reset \"\(lesson.title)\"?", isPresented: $confirmReset) {
            Button("Reset workspace and missions", role: .destructive) { model.resetCurrentLesson() }
        } message: {
            Text("This deletes everything in this lesson's folder, restores the starting files, and marks its missions as not done.")
        }
        .onChange(of: current) { showHint = false; showSolution = false }
    }

    // MARK: Pieces

    private func currentMission(_ index: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.action)
            Text("Mission \(index + 1)/\(total)")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
                .fixedSize()
            Text(lesson.missions[index].title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.textStrong)
                .lineLimit(2)
                .truncationMode(.tail)
                .help(lesson.missions[index].title)
        }
    }

    private var completeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 15)).foregroundStyle(Theme.success)
            Text("Lesson complete").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.textStrong)
            if let next = Curriculum.next(after: lesson) {
                Button("Next: \(next.title)") { model.goNext() }
                    .buttonStyle(.primary)
                    .controlSize(.small)
                    .lineLimit(1)
            }
        }
    }

    private var trailingControls: some View {
        HStack(spacing: 2) {
            if current != nil {
                StripToggle(icon: "lightbulb", label: "Hint", isOn: showHint) { showHint.toggle() }
                StripToggle(icon: "eye", label: "Solution", isOn: showSolution) { showSolution.toggle() }
            }
            StripToggle(icon: "list.bullet", label: "All missions", isOn: showList, iconOnly: true) { showList.toggle() }
            Menu {
                Button("Reset Lesson Workspace…") { confirmReset = true }
                Button("Show Workspace in Finder") { model.revealInFinder() }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 12, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(Theme.textFaint)
            .padding(.leading, 4)
            .help("Workspace options")
        }
    }

    /// One small bar per mission; done ones are green, the current one blue.
    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(model.isDone(lesson, i) ? Theme.success : (i == current ? Theme.action : Color(hex: 0xE4E5E8)))
                    .frame(height: 4)
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.doneCount(lesson))
    }

    @ViewBuilder
    private func details(_ index: Int) -> some View {
        let mission = lesson.missions[index]
        VStack(alignment: .leading, spacing: 8) {
            if showHint {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb").foregroundStyle(Theme.warning)
                    RichText(markdown: mission.hint, size: 12.5)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.warningSurface)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            if showSolution {
                CodeBlock(command: mission.solution) { model.terminal.type($0) }
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lesson.missions.enumerated()), id: \.offset) { index, mission in
                let done = model.isDone(lesson, index)
                Button { if !done { picked = index } } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(done ? Theme.success : Theme.borderStrong, lineWidth: 1.5)
                                .background(Circle().fill(done ? Theme.success : .clear))
                                .frame(width: 18, height: 18)
                            if done {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textFaint)
                            }
                        }
                        Text(mission.title)
                            .font(.system(size: 12.5, weight: index == current ? .semibold : .regular))
                            .foregroundStyle(done ? Theme.textFaint : Theme.textStrong)
                            .strikethrough(done, color: Theme.textFaint)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(index == current ? Theme.actionSurface : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(done)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Small text-plus-icon toggle used in the mission strip.
private struct StripToggle: View {
    let icon: String
    let label: String
    let isOn: Bool
    var iconOnly = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isOn && icon == "lightbulb" ? "lightbulb.fill" : icon)
                if !iconOnly { Text(label) }
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(isOn ? Theme.action : Theme.textFaint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isOn ? Theme.actionSurface : (hover ? Color(hex: 0xF1F2F3) : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(iconOnly ? label : (isOn ? "Hide \(label.lowercased())" : "Show \(label.lowercased())"))
    }
}

private struct WelcomeShellCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Your sandbox shell", systemImage: "terminal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textStrong)
                RichText(markdown: "This is a real bash shell with the `docker` CLI. Its `~` is a private sandbox folder and each lesson gets its own workspace inside it, but containers run on your real Docker engine. Lessons name everything `dz-…`, so **Docker → Clean Up Lab Resources** can tidy up afterwards.", size: 12.5)
                Button("Continue: \(model.continueLesson.title)") { model.open(model.continueLesson) }
                    .buttonStyle(.primary)
                    .padding(.top, 4)
            }
        }
    }
}

struct TerminalCard: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var terminal: TerminalController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(terminal.isRunning ? Color(hex: 0x3FB950) : Color(hex: 0xE5534B)).frame(width: 7, height: 7)
                Text(model.currentLesson.map { "bash · ~/\($0.id)" } ?? "bash · ~")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xA0A4AE))
                Spacer()
                Button { model.restartShell() } label: {
                    Label("Restart shell", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color(hex: 0xA0A4AE))
                }
                .buttonStyle(.plain)
                .help("Restart bash")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: 0x1A1B1F))

            ZStack {
                TerminalHost(view: terminal.view)
                    .padding(.leading, 8)
                    .padding(.vertical, 6)
                if !terminal.isRunning {
                    VStack(spacing: 10) {
                        Text("The shell exited.").foregroundStyle(Theme.codeText)
                        Button("Start a new shell") { model.restartShell() }.buttonStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.terminal.opacity(0.85))
                }
            }
            .background(Theme.terminal)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.4)))
        .frame(minHeight: 260, maxHeight: .infinity)
    }
}

/// Hosts the long-lived SwiftTerm view inside SwiftUI.
struct TerminalHost: NSViewRepresentable {
    let view: LocalProcessTerminalView

    func makeNSView(context: Context) -> LocalProcessTerminalView { view }
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
