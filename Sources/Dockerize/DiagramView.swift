import SwiftUI
import DockerizeCore

/// Draws a lesson diagram: pastel group boundaries, orthogonal arrows with
/// labels, and icon cards for nodes, in the style of HashiCorp's
/// architecture diagrams.
struct DiagramView: View {
    let diagram: Diagram

    private var layout: DiagramLayout { DiagramLayout(diagram) }

    var body: some View {
        let layout = layout
        GeometryReader { geo in
            let scale = max(0.66, min(1, geo.size.width / layout.size.width))
            ScrollView(.horizontal, showsIndicators: scale <= 0.66) {
                DiagramCanvas(diagram: diagram, layout: layout)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: layout.size.width * scale, height: layout.size.height * scale, alignment: .topLeading)
            }
            .frame(height: layout.size.height * scale)
            .preference(key: DiagramHeightKey.self, value: layout.size.height * scale)
        }
        .modifier(DiagramHeightModifier())
    }

}

/// The diagram at natural size, with no scrolling or scaling. Also used to
/// export PNGs, since ImageRenderer can't draw inside a ScrollView.
struct DiagramCanvas: View {
    let diagram: Diagram
    var layout: DiagramLayout

    init(diagram: Diagram, layout: DiagramLayout? = nil) {
        self.diagram = diagram
        self.layout = layout ?? DiagramLayout(diagram)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Groups
            ForEach(Array(layout.groups.enumerated()), id: \.offset) { index, group in
                let colors = Theme.groupFills[index % Theme.groupFills.count]
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors.fill)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(colors.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .frame(width: group.rect.width, height: group.rect.height)
                    .offset(x: group.rect.minX, y: group.rect.minY)
                Text(group.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textFaint)
                    .offset(x: group.rect.minX + 10, y: group.rect.minY + 7)
            }

            // Edges
            Canvas { ctx, _ in
                for edge in layout.edges {
                    var path = Path()
                    path.addLines(edge.points)
                    let style = StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round, dash: edge.dashed ? [5, 4] : [])
                    ctx.stroke(path, with: .color(Color(hex: 0x8C909C)), style: style)
                    ctx.fill(arrowHead(edge.points), with: .color(Color(hex: 0x6B6F7A)))
                }
            }
            .frame(width: layout.size.width, height: layout.size.height)

            // Edge labels
            ForEach(Array(layout.edges.enumerated()), id: \.offset) { _, edge in
                if let label = edge.label {
                    Text(label)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.surface.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: edge.labelWidth)
                        .fixedSize(horizontal: false, vertical: true)
                        .position(edge.labelPosition)
                }
            }

            // Nodes
            ForEach(diagram.nodes, id: \.id) { node in
                NodeCard(node: node)
                    .frame(width: DiagramLayout.nodeSize.width, height: DiagramLayout.nodeSize.height)
                    .position(layout.center(of: node))
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
    }

    private func arrowHead(_ points: [CGPoint]) -> Path {
        guard points.count >= 2 else { return Path() }
        let tip = points[points.count - 1]
        let from = points[points.count - 2]
        let angle = atan2(tip.y - from.y, tip.x - from.x)
        let length: CGFloat = 8, spread: CGFloat = .pi / 7
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread)))
        path.addLine(to: CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread)))
        path.closeSubpath()
        return path
    }
}

private struct NodeCard: View {
    let node: Diagram.Node

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 7)
                .fill(Theme.color(for: node.kind))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: node.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(node.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textStrong)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let detail = node.detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }
}

/// Grid geometry for a diagram, computed once per render.
struct DiagramLayout {
    static let nodeSize = CGSize(width: 150, height: 62)
    static let cell = CGSize(width: 244, height: 128)
    static let padding: CGFloat = 24
    static let groupInset: CGFloat = 14
    static let groupLabel: CGFloat = 20

    struct GroupBox { let label: String; let rect: CGRect }
    struct EdgePath {
        let points: [CGPoint]
        let dashed: Bool
        let label: String?
        let labelPosition: CGPoint
        let labelWidth: CGFloat
    }

    let diagram: Diagram
    let size: CGSize
    let groups: [GroupBox]
    let edges: [EdgePath]
    private let hasGroupOnTop: Bool

    init(_ diagram: Diagram) {
        self.diagram = diagram
        // Leave room above row 0 when a group label sits there.
        let topRowGrouped = diagram.groups.contains { g in
            g.members.contains { diagram.node($0)?.row == 0 }
        }
        hasGroupOnTop = topRowGrouped
        let top = Self.padding + (topRowGrouped ? Self.groupLabel : 0)
        size = CGSize(
            width: Self.padding * 2 + CGFloat(diagram.columns) * Self.cell.width,
            height: top + Self.padding + CGFloat(diagram.rows) * Self.cell.height
        )

        func center(_ node: Diagram.Node) -> CGPoint {
            CGPoint(
                x: Self.padding + (CGFloat(node.col) + 0.5) * Self.cell.width,
                y: top + (CGFloat(node.row) + 0.5) * Self.cell.height
            )
        }
        func frame(_ node: Diagram.Node) -> CGRect {
            let c = center(node)
            return CGRect(x: c.x - Self.nodeSize.width / 2, y: c.y - Self.nodeSize.height / 2,
                          width: Self.nodeSize.width, height: Self.nodeSize.height)
        }

        groups = diagram.groups.compactMap { group in
            let frames = group.members.compactMap { diagram.node($0) }.map(frame)
            guard let first = frames.first else { return nil }
            let union = frames.dropFirst().reduce(first) { $0.union($1) }
            let rect = union.insetBy(dx: -Self.groupInset, dy: -Self.groupInset)
            return GroupBox(label: group.label, rect: CGRect(x: rect.minX, y: rect.minY - Self.groupLabel,
                                                             width: rect.width, height: rect.height + Self.groupLabel))
        }

        let gapX = Self.cell.width - Self.nodeSize.width
        edges = diagram.edges.compactMap { edge in
            guard let a = diagram.node(edge.from), let b = diagram.node(edge.to) else { return nil }
            let fa = frame(a), fb = frame(b)
            var points: [CGPoint]
            var labelAt: CGPoint
            var labelWidth = gapX - 4

            if edge.loopBack {
                // U-turn below both nodes; lands right of centre so it doesn't
                // meet an edge leaving the target's bottom.
                let y = max(fa.maxY, fb.maxY) + 26
                let endX = fb.midX + Self.nodeSize.width / 4
                points = [
                    CGPoint(x: fa.midX, y: fa.maxY),
                    CGPoint(x: fa.midX, y: y),
                    CGPoint(x: endX, y: y),
                    CGPoint(x: endX, y: fb.maxY),
                ]
                labelAt = CGPoint(x: (fa.midX + endX) / 2, y: y)
                labelWidth = abs(fa.midX - endX) - 16
            } else if a.row == b.row {
                let y = fa.midY
                let (x1, x2) = a.col < b.col ? (fa.maxX, fb.minX) : (fa.minX, fb.maxX)
                points = [CGPoint(x: x1, y: y), CGPoint(x: x2, y: y)]
                labelAt = CGPoint(x: (x1 + x2) / 2, y: y - 14)
                if abs(a.col - b.col) > 1 { labelWidth = abs(x2 - x1) - 16 }
            } else if a.col == b.col {
                let x = fa.midX
                let (y1, y2) = a.row < b.row ? (fa.maxY, fb.minY) : (fa.minY, fb.maxY)
                points = [CGPoint(x: x, y: y1), CGPoint(x: x, y: y2)]
                labelAt = CGPoint(x: x, y: (y1 + y2) / 2)
                labelWidth = Self.nodeSize.width
            } else {
                // Leave sideways, turn in the gap between columns, enter sideways.
                let rightward = b.col > a.col
                let x1 = rightward ? fa.maxX : fa.minX
                let x2 = rightward ? fb.minX : fb.maxX
                let gapEdge = rightward ? fa.maxX + gapX / 2 : fa.minX - gapX / 2
                points = [
                    CGPoint(x: x1, y: fa.midY),
                    CGPoint(x: gapEdge, y: fa.midY),
                    CGPoint(x: gapEdge, y: fb.midY),
                    CGPoint(x: x2, y: fb.midY),
                ]
                labelAt = CGPoint(x: gapEdge, y: (fa.midY + fb.midY) / 2)
                labelWidth = Self.nodeSize.width
            }
            return EdgePath(points: points, dashed: edge.dashed, label: edge.label, labelPosition: labelAt, labelWidth: labelWidth)
        }
    }

    func center(of node: Diagram.Node) -> CGPoint {
        let top = Self.padding + (hasGroupOnTop ? Self.groupLabel : 0)
        return CGPoint(
            x: Self.padding + (CGFloat(node.col) + 0.5) * Self.cell.width,
            y: top + (CGFloat(node.row) + 0.5) * Self.cell.height
        )
    }
}

// GeometryReader takes all offered height, so measure the scaled diagram and
// pin the view to it.
private struct DiagramHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 200
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct DiagramHeightModifier: ViewModifier {
    @State private var height: CGFloat = 200
    func body(content: Content) -> some View {
        content
            .frame(height: height)
            .onPreferenceChange(DiagramHeightKey.self) { height = $0 }
    }
}

/// Small key explaining the node colors used in a diagram.
struct DiagramLegend: View {
    let diagram: Diagram

    var body: some View {
        let kinds = Array(Set(diagram.nodes.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
        HStack(spacing: 14) {
            ForEach(kinds, id: \.self) { kind in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.color(for: kind)).frame(width: 10, height: 10)
                    Text(Theme.label(for: kind)).font(.system(size: 11.5)).foregroundStyle(Theme.textFaint)
                }
            }
            HStack(spacing: 5) {
                Rectangle().fill(Color(hex: 0x8C909C)).frame(width: 16, height: 1.4)
                Text("flow").font(.system(size: 11.5)).foregroundStyle(Theme.textFaint)
                Text("- - -").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x8C909C))
                Text("optional / indirect").font(.system(size: 11.5)).foregroundStyle(Theme.textFaint)
            }
        }
    }
}
