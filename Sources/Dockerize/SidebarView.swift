import SwiftUI
import DockerizeCore

/// Dark side navigation in the style of the Vault UI: brand at the top, a
/// dashboard link, then the roadmap categories with chevrons that expand
/// into lessons. Like Obsidian, it folds down to a thin icon rail (click the
/// logo, the sidebar button, or press Cmd-\\).
struct SidebarView: View {
    static let fullWidth: CGFloat = 252
    static let railWidth: CGFloat = 52

    @EnvironmentObject var model: AppModel
    var collapsed = false
    @State private var expanded: Set<String> = []

    var body: some View {
        Group {
            if collapsed { rail } else { full }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.navBackground)
        .onAppear(perform: expandCurrent)
        .onChange(of: model.screen) { expandCurrent() }
    }

    // MARK: Collapsed rail

    private var rail: some View {
        VStack(spacing: 4) {
            logoButton
                .padding(.top, 14)
                .padding(.bottom, 14)
            RailButton(icon: "square.grid.2x2", title: "Dashboard", isActive: model.screen == .dashboard) {
                model.openDashboard()
            }
            RailButton(icon: "map", title: "Roadmap", isActive: model.screen == .roadmap) {
                model.openRoadmap()
            }
            RailButton(icon: "shippingbox", title: "Engine", isActive: model.screen == .engine) {
                model.openEngine()
            }
            RailButton(icon: "list.bullet.rectangle", title: "Cheat sheet", isActive: model.screen == .cheatSheet) {
                model.openCheatSheet()
            }
            Rectangle().fill(Theme.navActive).frame(width: 24, height: 1).padding(.vertical, 8)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(Curriculum.categories) { category in
                        RailButton(
                            icon: category.icon,
                            title: category.title,
                            isActive: model.currentLesson.flatMap { Curriculum.category(of: $0)?.id } == category.id
                        ) {
                            // Open the sidebar on that category so its lessons are visible.
                            expanded.insert(category.id)
                            model.toggleSidebar()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            let p = model.overallProgress
            Text("\(p.done)")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.navText)
                .help("Overall progress: \(p.done) of \(p.total) missions")
                .padding(.bottom, 4)
            EngineDot()
                .padding(.bottom, 8)
            RailButton(icon: "sidebar.left", title: "Show sidebar (⌘\\)", isActive: false) { model.toggleSidebar() }
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Expanded

    private var full: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .padding(.top, 14)
                .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    NavRow(icon: "square.grid.2x2", title: "Dashboard", isActive: model.screen == .dashboard) {
                        model.openDashboard()
                    }
                    NavRow(icon: "map", title: "Roadmap", isActive: model.screen == .roadmap) {
                        model.openRoadmap()
                    }
                    NavRow(icon: "shippingbox", title: "Engine", isActive: model.screen == .engine) {
                        model.openEngine()
                    }
                    NavRow(icon: "list.bullet.rectangle", title: "Cheat sheet", isActive: model.screen == .cheatSheet) {
                        model.openCheatSheet()
                    }

                    SectionLabel("Lessons")

                    ForEach(Curriculum.categories) { category in
                        categoryRow(category)
                        if expanded.contains(category.id) {
                            ForEach(category.lessons) { lesson in
                                lessonRow(lesson)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            footer
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            logoButton
            VStack(alignment: .leading, spacing: 0) {
                Text("Dockerize").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text("Learn Docker by using it").font(.system(size: 11)).foregroundStyle(Theme.navMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            RailButton(icon: "sidebar.left", title: "Hide sidebar (⌘\\)", isActive: false, size: 26) { model.toggleSidebar() }
        }
    }

    /// The container-stack mark doubles as the collapse toggle.
    private var logoButton: some View {
        Button { model.toggleSidebar() } label: {
            LogoMark(size: 28)
        }
        .buttonStyle(.plain)
        .help(collapsed ? "Show sidebar (⌘\\)" : "Hide sidebar (⌘\\)")
    }

    private func categoryRow(_ category: DockerizeCore.Category) -> some View {
        let p = model.progress(category)
        let isOpen = expanded.contains(category.id)
        return NavRow(
            icon: category.icon,
            title: category.title,
            isActive: false,
            trailing: AnyView(
                HStack(spacing: 8) {
                    if p.done == p.total {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Color(hex: 0x3FB950))
                    } else if p.done > 0 {
                        Text("\(p.done)/\(p.total)").font(.system(size: 10.5, weight: .medium)).foregroundStyle(Theme.navMuted)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.navMuted)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
            )
        ) {
            withAnimation(.easeOut(duration: 0.18)) {
                if isOpen { expanded.remove(category.id) } else { expanded.insert(category.id) }
            }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        let done = model.doneCount(lesson)
        let total = lesson.missions.count
        let active = model.screen == .lesson(lesson.id)
        let status: String = done == total ? "checkmark.circle.fill" : (done > 0 ? "circle.lefthalf.filled" : "circle")
        let statusColor: Color = done == total ? Color(hex: 0x3FB950) : (done > 0 ? Theme.brand : Color(hex: 0x5C5F68))

        return Button { model.open(lesson) } label: {
            HStack(spacing: 9) {
                Image(systemName: status).font(.system(size: 10)).foregroundStyle(statusColor)
                Text(lesson.title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(active ? .white : Theme.navText.opacity(0.85))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, 36)
            .padding(.trailing, 10)
            .padding(.vertical, 6)
            .background(active ? Theme.navActive : .clear)
            .overlay(alignment: .leading) {
                if active { Rectangle().fill(Theme.brand).frame(width: 2).padding(.leading, 22).padding(.vertical, 4) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        let p = model.overallProgress
        return VStack(alignment: .leading, spacing: 8) {
            EngineStatusRow()
                .padding(.bottom, 6)
            HStack {
                Text("Overall progress").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.navMuted)
                Spacer()
                Text("\(p.done)/\(p.total)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.navText)
            }
            ProgressBar(value: Double(p.done) / Double(max(p.total, 1)), tint: Theme.brand, height: 4)
        }
        .padding(16)
        .background(Color(hex: 0x15161A))
    }

    private func expandCurrent() {
        if let lesson = model.currentLesson, let category = Curriculum.category(of: lesson) {
            expanded.insert(category.id)
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.navMuted)
            .padding(.horizontal, 10)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}

private struct NavRow: View {
    let icon: String
    let title: String
    let isActive: Bool
    var trailing: AnyView? = nil
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundStyle(isActive ? .white : Theme.navText.opacity(0.8))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? .white : Theme.navText)
                Spacer()
                trailing
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? Theme.navActive : (hover ? Theme.navHover : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Square icon button used on the collapsed rail and for the sidebar toggle.
private struct RailButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var size: CGFloat = 34
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isActive ? .white : Theme.navText.opacity(hover ? 1 : 0.7))
                .frame(width: size, height: size)
                .background(isActive ? Theme.navActive : (hover ? Theme.navHover : .clear))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(title)
    }
}

/// Engine status for the dark sidebar footer: a dot, a label, and a Start
/// button when the daemon is down.
private struct EngineStatusRow: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var engine: EngineMonitor

    var body: some View {
        HStack(spacing: 8) {
            EngineDot()
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.navText)
                Text(detail).font(.system(size: 10.5)).foregroundStyle(Theme.navMuted).lineLimit(1)
            }
            Spacer(minLength: 4)
            if engine.status == .stopped {
                Button(engine.isStarting ? "Starting…" : "Start") { model.startEngine() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.action)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .disabled(engine.isStarting)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.openEngine() }
        .help("Open the Engine page")
    }

    private var title: String {
        switch engine.status {
        case .checking: return "Checking Docker…"
        case .notInstalled: return "Docker not installed"
        case .stopped: return engine.isStarting ? "Engine starting…" : "Engine stopped"
        case .running(let v): return "Engine \(v)"
        }
    }

    private var detail: String {
        switch engine.status {
        case .running:
            let n = engine.state?.containers.filter(\.isRunning).count ?? 0
            return "\(n) container\(n == 1 ? "" : "s") running"
        case .stopped: return engine.installedRuntime?.name ?? "Start Docker to do missions"
        case .notInstalled: return "See the Engine page"
        case .checking: return " "
        }
    }
}

/// Green when the engine is up, amber while starting, red when it's down.
struct EngineDot: View {
    @EnvironmentObject var engine: EngineMonitor

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.35), lineWidth: 3))
            .help(engine.status.isRunning ? "Docker engine is running" : "Docker engine is not running")
    }

    private var color: Color {
        switch engine.status {
        case .running: return Color(hex: 0x3FB950)
        case .checking: return Color(hex: 0x8C909C)
        case .stopped: return engine.isStarting ? Color(hex: 0xE3B341) : Color(hex: 0xE5534B)
        case .notInstalled: return Color(hex: 0xE5534B)
        }
    }
}
