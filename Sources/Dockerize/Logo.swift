import AppKit
import SwiftUI

/// The Dockerize mark, modelled on Docker's flat whale: a solid whale with a
/// stepped stack of containers (5, 3, 1) on its back, in one flat blue.
/// Shapes are defined in a unit square with y pointing down, so the same
/// geometry draws in SwiftUI and in a flipped NSImage.
enum LogoGeometry {
    static func whale(in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        p.move(to: pt(0.03, 0.50))                                                        // bow, top-left corner
        p.addLine(to: pt(0.755, 0.50))                                                    // flat deck
        p.addQuadCurve(to: pt(0.825, 0.285), control: pt(0.80, 0.46))                    // fluke's upper lobe
        p.addQuadCurve(to: pt(0.885, 0.395), control: pt(0.835, 0.37))                   // notch between lobes
        p.addQuadCurve(to: pt(0.99, 0.415), control: pt(0.935, 0.40))                    // fluke's lower lobe
        p.addCurve(to: pt(0.43, 0.89), control1: pt(0.93, 0.73), control2: pt(0.70, 0.89))  // stern to belly
        p.addCurve(to: pt(0.03, 0.50), control1: pt(0.17, 0.89), control2: pt(0.03, 0.72))  // round head
        p.closeSubpath()
        return p
    }

    /// The stacked containers: five on the deck, three above, one on top.
    static func containers(in rect: CGRect) -> [CGRect] {
        let size: CGFloat = 0.105, step: CGFloat = 0.13, left: CGFloat = 0.08
        func box(_ column: Int, _ row: Int) -> CGRect {
            CGRect(x: rect.minX + (left + CGFloat(column) * step) * rect.width,
                   y: rect.minY + (0.365 - CGFloat(row) * step) * rect.height,
                   width: size * rect.width, height: size * rect.height)
        }
        return (0..<5).map { box($0, 0) } + (1...3).map { box($0, 1) } + [box(3, 2)]
    }

    static let blue = NSColor(hex: 0x2496ED)
    static let backgroundTop = NSColor(hex: 0x161B26)
    static let backgroundBottom = NSColor(hex: 0x07090D)
}

/// The mark as a SwiftUI view, for the sidebar.
struct LogoMark: View {
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24)
            .fill(LinearGradient(colors: [Color(nsColor: LogoGeometry.backgroundTop), Color(nsColor: LogoGeometry.backgroundBottom)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: size * 0.24).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .frame(width: size, height: size)
            .overlay(
                Canvas { context, canvasSize in
                    let art = CGRect(origin: .zero, size: canvasSize).insetBy(dx: canvasSize.width * 0.12, dy: canvasSize.height * 0.12)
                    let blue = Color(nsColor: LogoGeometry.blue)
                    context.fill(Path(LogoGeometry.whale(in: art)), with: .color(blue))
                    for box in LogoGeometry.containers(in: art) {
                        context.fill(Path(roundedRect: box, cornerRadius: box.width * 0.12), with: .color(blue))
                    }
                }
            )
    }
}
