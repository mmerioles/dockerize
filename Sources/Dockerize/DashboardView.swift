import SwiftUI
import DockerizeCore

/// Landing page modelled on the Vault dashboard: a title row, then cards for
/// the roadmap, quick actions, and configuration details.
struct DashboardView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var engine: EngineMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text("Dockerize").font(.system(size: 26, weight: .semibold)).foregroundStyle(Theme.textStrong)
                        Badge(text: "v0.1.0")
                    }
                    Text("Learn Docker by using it. Read a lesson, look at the diagram, then run real containers in the shell beside it. Dockerize checks your work against the live engine.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                }

                if let error = model.setupError {
                    InlineAlert(title: "Setup problem", message: error, icon: "exclamationmark.triangle", tone: .warning)
                }

                HStack(alignment: .top, spacing: 16) {
                    quickActions
                    configuration
                }
                .fixedSize(horizontal: false, vertical: true)
                roadmapCard
            }
            .padding(32)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .background(Theme.page)
    }

    private var roadmapCard: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "Roadmap", subtitle: "\(Curriculum.categories.count) sections · \(Curriculum.lessons.count) lessons") {
                    Button("View roadmap") { model.openRoadmap() }
                        .buttonStyle(.tertiary)
                }
                .padding(20)
                Divider().overlay(Theme.border)
                ForEach(Array(Curriculum.categories.enumerated()), id: \.element.id) { index, category in
                    let p = model.progress(category)
                    Button { model.open(category.lessons.first { !model.isComplete($0) } ?? category.lessons[0]) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: category.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.action)
                                .frame(width: 30, height: 30)
                                .background(Theme.actionSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(category.title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.textStrong)
                                Text(category.blurb).font(.system(size: 12)).foregroundStyle(Theme.textFaint).lineLimit(1)
                            }
                            .layoutPriority(1)
                            Spacer(minLength: 12)
                            VStack(alignment: .trailing, spacing: 5) {
                                Text("\(p.done)/\(p.total)").font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.text)
                                ProgressBar(value: Double(p.done) / Double(max(p.total, 1))).frame(width: 90)
                            }
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textFaint)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < Curriculum.categories.count - 1 { Divider().overlay(Theme.border).padding(.leading, 64) }
                }
            }
        }
    }

    private var quickActions: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(title: "Quick actions")
                VStack(alignment: .leading, spacing: 6) {
                    Text("PICK UP WHERE YOU LEFT OFF").font(.system(size: 10.5, weight: .semibold)).tracking(0.6).foregroundStyle(Theme.textFaint)
                    Button { model.open(model.continueLesson) } label: {
                        HStack { Text(model.continueLesson.title); Spacer(); Image(systemName: "arrow.right") }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("DAY TO DAY").font(.system(size: 10.5, weight: .semibold)).tracking(0.6).foregroundStyle(Theme.textFaint)
                    HStack(spacing: 8) {
                        Button { model.openEngine() } label: { Label("Engine", systemImage: "shippingbox") }
                            .buttonStyle(.secondary)
                        Button { model.openCheatSheet() } label: { Label("Cheat sheet", systemImage: "list.bullet.rectangle") }
                            .buttonStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("JUMP TO A LESSON").font(.system(size: 10.5, weight: .semibold)).tracking(0.6).foregroundStyle(Theme.textFaint)
                    Menu {
                        ForEach(Curriculum.categories) { category in
                            Section(category.title) {
                                ForEach(category.lessons) { lesson in
                                    Button(lesson.title) { model.open(lesson) }
                                }
                            }
                        }
                    } label: {
                        Text("Select a lesson")
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.borderStrong))
                }
            }
        }
    }

    private var configuration: some View {
        let p = model.overallProgress
        return Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "Configuration details").padding(20)
                ConfigRow(key: "Engine", value: engineValue)
                ConfigRow(key: "Docker CLI", value: [engine.clientVersion, engine.probe.executable].compactMap { $0 }.joined(separator: " · ").ifEmpty("not found"))
                ConfigRow(key: "Runtime", value: engine.installedRuntime?.name ?? "Colima or another engine")
                ConfigRow(key: "Shell", value: "/bin/bash \(model.bashVersion)")
                ConfigRow(key: "Sandbox HOME", value: model.workspace.home.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                ConfigRow(key: "Lessons", value: "\(Curriculum.lessons.count)")
                ConfigRow(key: "Missions done", value: "\(p.done) of \(p.total)", last: true)
            }
        }
    }
}

private extension DashboardView {
    var engineValue: String {
        switch engine.status {
        case .checking: return "checking…"
        case .notInstalled: return "not installed"
        case .stopped: return "stopped"
        case .running(let v): return "running · \(v)"
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

private struct ConfigRow: View {
    let key: String
    let value: String
    var last = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).font(.system(size: 12.5)).foregroundStyle(Theme.textFaint).frame(width: 110, alignment: .leading)
            Text(value)
                .font(Theme.monoSmall)
                .foregroundStyle(Theme.textStrong)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Divider().overlay(Theme.border) }
        .padding(.bottom, last ? 6 : 0)
    }
}
