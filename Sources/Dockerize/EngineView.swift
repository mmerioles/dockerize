import SwiftUI
import DockerizeCore

/// A live look at the Docker engine, laid out like a Vault list page: a status
/// card, then tabs for containers, images, volumes and networks. Row actions
/// type the matching command into the shell rather than running it, so you
/// see (and learn) exactly what happens.
struct EngineView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var engine: EngineMonitor

    enum Tab: String, CaseIterable, Identifiable {
        case containers = "Containers", images = "Images", volumes = "Volumes", networks = "Networks"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .containers: return "shippingbox"
            case .images: return "square.stack.3d.up"
            case .volumes: return "externaldrive"
            case .networks: return "network"
            }
        }
    }

    @State private var tab: Tab = .containers
    @AppStorage("dockerize.engine.labOnly") private var labOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusCard
                if engine.status.isRunning, let state = engine.state {
                    resources(state)
                } else if engine.status == .notInstalled {
                    installCard
                }
            }
            .padding(32)
            .frame(maxWidth: 1000, alignment: .leading)
        }
        .background(Theme.page)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Engine").font(.system(size: 26, weight: .semibold)).foregroundStyle(Theme.textStrong)
                Spacer()
                Button { model.refreshEngine() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .buttonStyle(.secondary)
            }
            Text("What's on your Docker engine right now. The buttons type the command into the shell for you to run, so you can see how each one works.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: 680, alignment: .leading)
        }
    }

    // MARK: Status

    private var statusCard: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    EngineDot()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textStrong)
                        Text(statusDetail).font(.system(size: 12.5)).foregroundStyle(Theme.textFaint)
                    }
                    Spacer()
                    if engine.status == .stopped {
                        Button(engine.isStarting ? "Starting…" : startLabel) { model.startEngine() }
                            .buttonStyle(.primary)
                            .disabled(engine.isStarting)
                    } else if engine.status.isRunning {
                        Button("Clean up lab resources…") {
                            (NSApp.delegate as? AppDelegate)?.confirmCleanup(model)
                        }
                        .buttonStyle(.secondary)
                        .disabled(engine.labResources.isEmpty)
                        .help("Remove everything named dz-… that the lessons created")
                    }
                }
                .padding(20)
                if engine.status.isRunning, let state = engine.state {
                    Divider().overlay(Theme.border)
                    // Wraps onto a second row when the lesson pane is narrow.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 0)], spacing: 0) {
                        Stat(label: "Running", value: "\(state.containers.filter(\.isRunning).count)", icon: "play.circle")
                        Stat(label: "Containers", value: "\(state.containers.count)", icon: "shippingbox")
                        Stat(label: "Images", value: "\(state.images.count)", icon: "square.stack.3d.up")
                        Stat(label: "Volumes", value: "\(state.volumes.count)", icon: "externaldrive")
                        Stat(label: "Networks", value: "\(state.networks.count)", icon: "network")
                    }
                }
            }
        }
    }

    private var startLabel: String {
        engine.installedRuntime.map { "Start \($0.name)" } ?? "Run colima start"
    }

    private var statusTitle: String {
        switch engine.status {
        case .checking: return "Checking the Docker engine…"
        case .notInstalled: return "Docker isn't installed"
        case .stopped: return engine.isStarting ? "Engine starting…" : "Engine stopped"
        case .running(let v): return "Engine running · Docker \(v)"
        }
    }

    private var statusDetail: String {
        var parts: [String] = []
        if let client = engine.clientVersion { parts.append("CLI \(client)") }
        if let runtime = engine.installedRuntime { parts.append(runtime.name) }
        if let path = engine.probe.executable { parts.append(path) }
        if engine.status == .stopped && !engine.isStarting { parts.insert("The CLI can't reach the daemon", at: 0) }
        if let t = engine.lastUpdated { parts.append("updated \(t.formatted(date: .omitted, time: .standard))") }
        return parts.joined(separator: " · ")
    }

    private var installCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Install a Docker runtime", subtitle: "On a Mac, containers run in a small Linux VM. Any of these gives you that VM plus the docker CLI.")
                CodeBlock(command: "brew install --cask orbstack", output: "Fast and light. Opens a menu bar app that runs the engine.") { model.terminal.type($0) }
                CodeBlock(command: "brew install --cask docker", output: "Docker Desktop: Docker's official app.") { model.terminal.type($0) }
                CodeBlock(command: "brew install colima docker docker-compose && colima start", output: "Colima: open source, command line only.") { model.terminal.type($0) }
            }
        }
    }

    // MARK: Resources

    private func resources(_ state: DockerState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Toggle("Only dz- lab resources", isOn: $labOnly)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12.5))
                    .fixedSize()
            }
            .padding(.bottom, 8)
            HStack(spacing: 22) {
                ForEach(Tab.allCases) { t in
                    Button { tab = t } label: {
                        VStack(spacing: 8) {
                            Label("\(t.rawValue) \(count(t, state))", systemImage: t.icon)
                                .font(.system(size: 13, weight: tab == t ? .semibold : .medium))
                                .foregroundStyle(tab == t ? Theme.action : Theme.text)
                            Rectangle().fill(tab == t ? Theme.action : .clear).frame(height: 2)
                        }
                        .fixedSize()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            Divider().overlay(Theme.border)
            Card(padding: 0) {
                VStack(spacing: 0) {
                    switch tab {
                    case .containers: containerRows(state)
                    case .images: imageRows(state)
                    case .volumes: simpleRows(filter(state.volumes), icon: "externaldrive", kind: "volume")
                    case .networks: simpleRows(filter(state.networks), icon: "network", kind: "network")
                    }
                }
            }
            .padding(.top, 16)
        }
    }

    private func count(_ tab: Tab, _ state: DockerState) -> Int {
        switch tab {
        case .containers: return containers(state).count
        case .images: return images(state).count
        case .volumes: return filter(state.volumes).count
        case .networks: return filter(state.networks).count
        }
    }

    private func isLab(_ name: String) -> Bool {
        (name.split(separator: "/").last.map(String.init) ?? name).hasPrefix(Curriculum.prefix)
    }

    private func filter(_ names: [String]) -> [String] { labOnly ? names.filter(isLab) : names }
    private func containers(_ s: DockerState) -> [DockerState.Container] {
        (labOnly ? s.containers.filter { isLab($0.name) } : s.containers)
            .sorted { ($0.isRunning ? 0 : 1, $0.name) < ($1.isRunning ? 0 : 1, $1.name) }
    }
    private func images(_ s: DockerState) -> [DockerState.Image] {
        labOnly ? s.images.filter { isLab($0.repository) } : s.images
    }

    @ViewBuilder
    private func containerRows(_ state: DockerState) -> some View {
        let list = containers(state)
        if list.isEmpty {
            empty("No containers yet.", command: "docker run -d --name dz-hello -p 8080:80 \(Img.nginx)")
        }
        ForEach(Array(list.enumerated()), id: \.element.name) { i, c in
            ResourceRow(
                icon: "shippingbox",
                iconTint: c.isRunning ? Theme.success : Theme.textFaint,
                title: c.name,
                subtitle: [c.image, c.status, c.ports.isEmpty ? nil : c.publishedPorts.sorted().map { "localhost:\($0)" }.joined(separator: " ")]
                    .compactMap { $0 }.joined(separator: " · "),
                badge: Badge(text: c.state, tone: c.isRunning ? .success : .neutral),
                first: i == 0
            ) {
                if c.isRunning {
                    Button("Logs") { model.terminal.type("docker logs --tail 50 \(c.name)") }
                    Button("Shell") { model.terminal.type("docker exec -it \(c.name) sh") }
                    Button("Stop") { model.terminal.type("docker stop \(c.name)") }
                } else {
                    Button("Start") { model.terminal.type("docker start \(c.name)") }
                }
                Button("Inspect") { model.terminal.type("docker inspect \(c.name) | less") }
                Button("Remove") { model.terminal.type("docker rm -f \(c.name)") }
            }
        }
    }

    @ViewBuilder
    private func imageRows(_ state: DockerState) -> some View {
        let list = images(state)
        if list.isEmpty {
            empty("No images yet.", command: "docker pull \(Img.alpine)")
        }
        ForEach(Array(list.enumerated()), id: \.element.reference) { i, img in
            ResourceRow(
                icon: "square.stack.3d.up",
                iconTint: Theme.action,
                title: img.reference,
                subtitle: [img.id, img.size].filter { !$0.isEmpty }.joined(separator: " · "),
                badge: nil,
                first: i == 0
            ) {
                Button("Run") { model.terminal.type("docker run --rm -it \(img.reference) sh") }
                Button("History") { model.terminal.type("docker history \(img.reference)") }
                Button("Remove") { model.terminal.type("docker rmi \(img.reference)") }
            }
        }
    }

    @ViewBuilder
    private func simpleRows(_ names: [String], icon: String, kind: String) -> some View {
        if names.isEmpty {
            empty("No \(kind)s yet.", command: "docker \(kind) create dz-\(kind == "volume" ? "data" : "net")")
        }
        ForEach(Array(names.enumerated()), id: \.element) { i, name in
            let builtIn = kind == "network" && ["bridge", "host", "none"].contains(name)
            ResourceRow(icon: icon, iconTint: Theme.action, title: name, subtitle: builtIn ? "built in" : kind,
                        badge: nil, first: i == 0) {
                Button("Inspect") { model.terminal.type("docker \(kind) inspect \(name)") }
                if !builtIn {
                    Button("Remove") { model.terminal.type("docker \(kind) rm \(name)") }
                }
            }
        }
    }

    private func empty(_ text: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.textFaint)
            CodeBlock(command: command) { model.terminal.type($0) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Stat: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.action).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.textStrong)
                Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.textFaint).lineLimit(1).fixedSize()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }
}

/// One row in a Vault-style list: icon, name, details, and a "…" actions menu.
private struct ResourceRow<Actions: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String
    let badge: Badge?
    let first: Bool
    @ViewBuilder var actions: Actions
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(iconTint)
                .frame(width: 28, height: 28)
                .background(Color(hex: 0xF1F2F3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textStrong)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if let badge { badge }
            Menu { actions } label: {
                Image(systemName: "ellipsis").font(.system(size: 12, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(Theme.textFaint)
            .help("Type a command for this into the shell")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(hover ? Color(hex: 0xFAFAFA) : .clear)
        .overlay(alignment: .top) { if !first { Divider().overlay(Theme.border) } }
        .onHover { hover = $0 }
    }
}
