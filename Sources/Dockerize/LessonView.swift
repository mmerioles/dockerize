import SwiftUI
import DockerizeCore

enum LessonTab: String, CaseIterable, Identifiable {
    case learn = "Learn"
    case diagram = "Diagram"
    case reference = "Reference"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .learn: return "book"
        case .diagram: return "point.3.connected.trianglepath.dotted"
        case .reference: return "list.bullet.rectangle"
        }
    }
}

struct LessonView: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    @State private var tab: LessonTab = .learn

    private var category: DockerizeCore.Category? { Curriculum.category(of: lesson) }
    private var number: Int { (Curriculum.lessons.firstIndex(of: lesson) ?? 0) + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 32)
                .padding(.top, 22)
            TabBar(selection: $tab, tags: lesson.commands)
                .padding(.horizontal, 32)
                .padding(.top, 18)
            Divider().overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch tab {
                    case .learn: learn
                    case .diagram: diagram
                    case .reference: reference
                    }
                    pager
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: 900, alignment: .leading)
            }
        }
        .background(Theme.page)
        .id(lesson.id)   // reset scroll position and tab when the lesson changes
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button("Dashboard") { model.openDashboard() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.action)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textFaint)
                Text(category?.title ?? "").foregroundStyle(Theme.textFaint)
                Text("·").foregroundStyle(Theme.textFaint)
                Text("Lesson \(number) of \(Curriculum.lessons.count)").foregroundStyle(Theme.textFaint)
            }
            .lineLimit(1)
            .font(.system(size: 12.5))

            HStack(alignment: .center, spacing: 10) {
                Text(lesson.title)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.textStrong)
                if model.isComplete(lesson) {
                    Badge(text: "Complete", tone: .success, icon: "checkmark")
                }
            }

            RichText(markdown: lesson.summary, size: 14)
                .frame(maxWidth: 760, alignment: .leading)

            MissionStrip(lesson: lesson)
                .padding(.top, 4)
            LessonEngineBanner(lesson: lesson)
        }
    }

    // MARK: Tabs

    private var learn: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(Array(lesson.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.heading)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textStrong)
                    ForEach(paragraphs(section.body), id: \.self) { RichText(markdown: $0) }
                    if let example = section.example {
                        CodeBlock(command: example.command, output: example.output) { model.terminal.type($0) }
                            .padding(.top, 4)
                    }
                }
            }
            if let note = lesson.macNote {
                InlineAlert(title: "Docker on a Mac", message: note, icon: "laptopcomputer")
            }
            Card(padding: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.action)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.diagram.title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.textStrong)
                        Text("See how this works under the hood.").font(.system(size: 12.5)).foregroundStyle(Theme.textFaint)
                    }
                    Spacer()
                    Button("View diagram") { tab = .diagram }.buttonStyle(.secondary)
                }
            }
        }
    }

    private var diagram: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(title: lesson.diagram.title)
                DiagramView(diagram: lesson.diagram)
                RichText(markdown: lesson.diagram.caption, size: 13.5)
                Divider().overlay(Theme.border)
                DiagramLegend(diagram: lesson.diagram)
            }
        }
    }

    private var reference: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "Command reference", subtitle: "The options you'll reach for most. Run man <command> for everything else.")
                    .padding(20)
                HStack {
                    Text("COMMAND").frame(width: 240, alignment: .leading)
                    Text("WHAT IT DOES")
                    Spacer()
                }
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textFaint)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(hex: 0xF7F7F8))
                .overlay(alignment: .top) { Divider().overlay(Theme.border) }
                .overlay(alignment: .bottom) { Divider().overlay(Theme.border) }

                ForEach(Array(lesson.reference.enumerated()), id: \.offset) { index, option in
                    HStack(alignment: .firstTextBaseline) {
                        Text(option.syntax)
                            .font(Theme.mono)
                            .foregroundStyle(Theme.textStrong)
                            .textSelection(.enabled)
                            .frame(width: 240, alignment: .leading)
                        Text(option.meaning).font(.system(size: 13)).foregroundStyle(Theme.text)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if index < lesson.reference.count - 1 { Divider().overlay(Theme.border) }
                    }
                }
            }
        }
    }

    private var pager: some View {
        HStack {
            if let prev = Curriculum.previous(before: lesson) {
                Button { model.open(prev) } label: {
                    Label(prev.title, systemImage: "arrow.left")
                }
                .buttonStyle(.secondary)
            }
            Spacer()
            if let next = Curriculum.next(after: lesson) {
                Button { model.open(next) } label: {
                    HStack(spacing: 6) { Text("Next: \(next.title)"); Image(systemName: "arrow.right") }
                }
                .buttonStyle(.primary)
            }
        }
        .padding(.top, 8)
    }

    private func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

/// Helios-style tabs: text with a blue underline on the selected one.
struct TabBar: View {
    @Binding var selection: LessonTab
    /// Command names shown at the trailing edge when there's room.
    var tags: [String] = []

    var body: some View {
        HStack(spacing: 22) {
            ForEach(LessonTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 8) {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.system(size: 13, weight: selection == tab ? .semibold : .medium))
                            .foregroundStyle(selection == tab ? Theme.action : Theme.text)
                        Rectangle()
                            .fill(selection == tab ? Theme.action : .clear)
                            .frame(height: 2)
                    }
                    .fixedSize()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 12)
            // Drop the command tags rather than crowd the tabs on narrow layouts.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    ForEach(tags, id: \.self) { Badge(text: $0, tone: .highlight, mono: true) }
                }
                .fixedSize()
                .padding(.bottom, 10)
                Color.clear.frame(width: 0, height: 0)
            }
        }
    }
}

/// Shown under the missions when the lesson needs something from Docker: the
/// engine is down, or the lesson's images haven't been pulled yet.
struct LessonEngineBanner: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var engine: EngineMonitor
    let lesson: Lesson

    var body: some View {
        let needsEngine = lesson.usesDockerState || !lesson.images.isEmpty
            || lesson.missions.contains { $0.solution.contains("docker") }
        if needsEngine && !model.isComplete(lesson) {
            switch engine.status {
            case .notInstalled:
                banner(icon: "exclamationmark.triangle.fill", tone: Theme.warning, surface: Theme.warningSurface, border: Theme.warningBorder,
                       text: "The `docker` CLI wasn't found. Install OrbStack, Docker Desktop or Colima to do these missions.") {
                    Button("How to install") { model.openEngine() }.buttonStyle(.secondary).controlSize(.small)
                }
            case .stopped:
                banner(icon: "bolt.slash.fill", tone: Theme.warning, surface: Theme.warningSurface, border: Theme.warningBorder,
                       text: engine.isStarting ? "Starting the Docker engine…" : "The Docker engine isn't running. Missions here check real containers, so start it first.") {
                    Button(engine.isStarting ? "Starting…" : "Start Docker") { model.startEngine() }
                        .buttonStyle(.primary).controlSize(.small).disabled(engine.isStarting)
                }
            case .running:
                let missing = model.missingImages(lesson)
                if !missing.isEmpty {
                    banner(icon: "arrow.down.circle", tone: Theme.action, surface: Theme.actionSurface, border: Color(hex: 0xCCE0FF),
                           text: "This lesson uses " + missing.map { "`\($0)`" }.joined(separator: ", ") + ". Pull \(missing.count == 1 ? "it" : "them") now so the missions run fast.") {
                        Button("Pull \(missing.count == 1 ? "image" : "images")") { model.pullImages(missing) }
                            .buttonStyle(.secondary).controlSize(.small)
                    }
                }
            case .checking:
                EmptyView()
            }
        }
    }

    private func banner<Action: View>(icon: String, tone: Color, surface: Color, border: Color, text: String,
                                      @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tone)
            RichText(markdown: text, size: 12.5)
            Spacer(minLength: 8)
            action()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(border))
    }
}
