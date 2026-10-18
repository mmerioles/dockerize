import AppKit
import SwiftUI
import DockerizeCore

@main
struct DockerizeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Dockerize") {
            RootView()
                .environmentObject(model)
                .environmentObject(model.terminal)
                .environmentObject(model.engine)
                .frame(minWidth: 1100, minHeight: 700)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1480, height: 920)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(before: .toolbar) {
                Button(model.sidebarCollapsed ? "Show Sidebar" : "Hide Sidebar") { model.toggleSidebar() }
                    .keyboardShortcut("\\", modifiers: .command)
                Divider()
            }
            CommandMenu("Lesson") {
                Button("Dashboard") { model.openDashboard() }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Roadmap") { model.openRoadmap() }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Engine") { model.openEngine() }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Cheat Sheet") { model.openCheatSheet() }
                    .keyboardShortcut("4", modifiers: .command)
                Divider()
                Button("Previous Lesson") { model.goPrevious() }
                    .keyboardShortcut("[", modifiers: .command)
                Button("Next Lesson") { model.goNext() }
                    .keyboardShortcut("]", modifiers: .command)
                Divider()
                Button("Reset Lesson Workspace") { model.resetCurrentLesson() }
                    .disabled(model.currentLesson == nil)
                Button("Show Workspace in Finder") { model.revealInFinder() }
                Button("Restart Shell") { model.restartShell() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Reset All Progress…") { delegate.confirmResetAll(model) }
            }
            CommandMenu("Docker") {
                Button("Pull This Lesson's Images") { model.currentLesson.map { model.pullImages($0.images) } }
                    .disabled((model.currentLesson?.images ?? []).isEmpty)
                Button("Start Docker Engine") { model.startEngine() }
                Button("Refresh Engine State") { model.refreshEngine() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Clean Up Lab Resources…") { delegate.confirmCleanup(model) }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `Dockerize --export-diagrams DIR` writes every lesson diagram as a PNG and quits.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--export-diagrams"), i + 1 < args.count {
            MainActor.assumeIsolated { DiagramExporter.export(to: URL(fileURLWithPath: args[i + 1])) }
            exit(0)
        }
        // `Dockerize --export-icon FILE.png` writes the 1024px app icon (for the .icns) and quits.
        if let i = args.firstIndex(of: "--export-icon"), i + 1 < args.count {
            let image = Self.makeIcon(size: 1024)
            if let tiff = image.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: args[i + 1]))
            }
            exit(0)
        }
        // Running via `swift run` there is no app bundle, so ask for a normal
        // Dock icon and menu bar explicitly.
        NSApp.applicationIconImage = Self.makeIcon()
        // A screenshot run stays in the background, with no Dock icon or focus change.
        if Screenshots.isActive {
            NSApp.setActivationPolicy(.accessory)
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @MainActor
    func confirmResetAll(_ model: AppModel) {
        let alert = NSAlert()
        alert.messageText = "Reset all progress?"
        alert.informativeText = "Every mission will be marked as not done. Your workspace files are kept."
        alert.addButton(withTitle: "Reset Progress")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { model.resetAllProgress() }
    }

    /// Removes every `dz-` container, image, volume and network after asking.
    @MainActor
    func confirmCleanup(_ model: AppModel) {
        let engine = model.engine
        guard engine.status.isRunning else {
            let alert = NSAlert()
            alert.messageText = "Docker isn't running"
            alert.informativeText = "Start the Docker engine first, then clean up."
            alert.runModal()
            return
        }
        let lab = engine.labResources
        let alert = NSAlert()
        if lab.isEmpty {
            alert.messageText = "Nothing to clean up"
            alert.informativeText = "There are no containers, images, volumes or networks named dz-… on this engine."
            alert.runModal()
            return
        }
        alert.messageText = "Remove lab resources?"
        alert.informativeText = "This force-removes \(lab.summary) whose names start with \"dz-\". Nothing else on your engine is touched."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        engine.removeLabResources { error in
            guard let error else { return }
            let failed = NSAlert()
            failed.messageText = "Some resources couldn't be removed"
            failed.informativeText = error
            failed.runModal()
        }
    }

    /// Docker-blue rounded square with a stack of shipping containers.
    static func makeIcon(size side: CGFloat = 512) -> NSImage {
        let size = NSSize(width: side, height: side)
        let k = side / 512
        return NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 40 * k, dy: 40 * k)
            let background = NSGradient(starting: NSColor(hex: 0x2496ED), ending: NSColor(hex: 0x1060FF))
            background?.draw(in: NSBezierPath(roundedRect: inset, xRadius: 92 * k, yRadius: 92 * k), angle: -90)
            LogoGeometry.boxes(in: inset.insetBy(dx: 72 * k, dy: 86 * k)).forEach { box in
                NSColor.white.setFill()
                NSBezierPath(roundedRect: box, xRadius: 10 * k, yRadius: 10 * k).fill()
                // Corrugation lines, like a shipping container's side.
                NSColor(hex: 0x1D63ED).withAlphaComponent(0.35).setFill()
                let ribs = 4
                for i in 1...ribs {
                    let x = box.minX + box.width * CGFloat(i) / CGFloat(ribs + 1)
                    NSBezierPath(rect: NSRect(x: x - 2.5 * k, y: box.minY + box.height * 0.2, width: 5 * k, height: box.height * 0.6)).fill()
                }
            }
            return true
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(collapsed: model.sidebarCollapsed)
                .frame(width: model.sidebarCollapsed ? SidebarView.railWidth : SidebarView.fullWidth)
                .clipped()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.page)
        .onAppear {
            model.startShell()
            if Screenshots.isActive { Task { await Screenshots.run(model) } }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.screen {
        case .roadmap:
            // The roadmap needs the full width; the shell keeps running.
            RoadmapView()
        case .engine:
            workbench { EngineView() }
        case .cheatSheet:
            workbench { CheatSheetView() }
        case .dashboard:
            workbench { DashboardView() }
        case .lesson(let id):
            if let lesson = Curriculum.lesson(id) {
                workbench { LessonView(lesson: lesson) }
            }
        }
    }

    private func workbench<Main: View>(@ViewBuilder _ main: () -> Main) -> some View {
        SplitPane(minLeading: 380, minTrailing: 360) {
            main()
        } trailing: {
            WorkbenchPanel()
        }
    }
}

/// Two panes side by side, split evenly by default, with a draggable divider.
/// The split is stored as a fraction so it survives window resizes and relaunches.
struct SplitPane<Leading: View, Trailing: View>: View {
    var minLeading: CGFloat
    var minTrailing: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @AppStorage("dockerize.splitFraction") private var fraction: Double = 0.5
    @State private var dragStart: Double?

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            let leadingWidth = clampedWidth(total * fraction, total: total)
            HStack(spacing: 0) {
                leading
                    .frame(width: leadingWidth)
                    .frame(maxHeight: .infinity)
                divider(total: total)
                trailing
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func divider(total: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .overlay(
                // Wider invisible grab area around the hairline.
                Color.clear
                    .frame(width: 9)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let start = dragStart ?? fraction
                                if dragStart == nil { dragStart = start }
                                let width = clampedWidth(total * start + value.translation.width, total: total)
                                fraction = Double(width / max(total, 1))
                            }
                            .onEnded { _ in dragStart = nil }
                    )
                    .onTapGesture(count: 2) { fraction = 0.5 }   // double-click resets to half
            )
            .help("Drag to resize. Double-click to split evenly.")
    }

    private func clampedWidth(_ width: CGFloat, total: CGFloat) -> CGFloat {
        let upper = max(minLeading, total - minTrailing - 1)
        return min(max(width, minLeading), upper)
    }
}

@MainActor
enum DiagramExporter {
    static func export(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for lesson in Curriculum.lessons {
            // Flag arrows that start or end at the same point, which usually means they overlap.
            var anchors: [String: Int] = [:]
            for edge in DiagramLayout(lesson.diagram).edges {
                for p in [edge.points.first!, edge.points.last!] {
                    anchors["\(Int(p.x)),\(Int(p.y))", default: 0] += 1
                }
            }
            for (point, count) in anchors where count > 1 {
                print("warning: \(lesson.id): \(count) arrows meet at \(point)")
            }
            let view = VStack(alignment: .leading, spacing: 12) {
                Text(lesson.diagram.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textStrong)
                DiagramCanvas(diagram: lesson.diagram)
            }
            .padding(20)
            .background(Color.white)
            .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: dir.appendingPathComponent("\(lesson.id).png"))
        }
    }
}
