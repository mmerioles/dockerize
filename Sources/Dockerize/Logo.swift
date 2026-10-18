import AppKit
import SwiftUI

/// The Dockerize mark: a whale silhouette carrying a small stack of
/// containers. Shapes are defined in a unit square with y pointing down, so
/// the same geometry draws in SwiftUI and in a flipped NSImage.
enum LogoGeometry {
    /// The whale's body with the eye cut out (fill with even-odd).
    static func whale(in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        p.move(to: pt(0.05, 0.56))                                              // nose
        p.addQuadCurve(to: pt(0.22, 0.43), control: pt(0.07, 0.44))            // forehead
        p.addLine(to: pt(0.68, 0.43))                                           // flat back
        p.addQuadCurve(to: pt(0.83, 0.50), control: pt(0.77, 0.43))            // back to tail stock
        p.addQuadCurve(to: pt(0.955, 0.27), control: pt(0.905, 0.45))          // tail rising to a point
        p.addQuadCurve(to: pt(0.90, 0.58), control: pt(0.995, 0.45))           // fluke's outer edge
        p.addCurve(to: pt(0.52, 0.76), control1: pt(0.84, 0.70), control2: pt(0.68, 0.76))   // belly
        p.addCurve(to: pt(0.05, 0.56), control1: pt(0.30, 0.76), control2: pt(0.07, 0.72))   // chin
        p.closeSubpath()
        let r = 0.026 * rect.width
        let eye = pt(0.19, 0.555)
        p.addEllipse(in: CGRect(x: eye.x - r, y: eye.y - r, width: r * 2, height: r * 2))
        return p
    }

    /// Three containers stacked 2 + 1 on the whale's back.
    static func containers(in rect: CGRect) -> [CGRect] {
        func box(_ x: CGFloat, _ y: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height,
                   width: 0.135 * rect.width, height: 0.10 * rect.height)
        }
        return [box(0.315, 0.305), box(0.475, 0.305), box(0.395, 0.18)]
    }

    static let whaleTop = NSColor(hex: 0x4AABF2)
    static let whaleBottom = NSColor(hex: 0x1D63ED)
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
                    let art = CGRect(origin: .zero, size: canvasSize).insetBy(dx: canvasSize.width * 0.08, dy: canvasSize.height * 0.08)
                    let gradient = Gradient(colors: [Color(nsColor: LogoGeometry.whaleTop), Color(nsColor: LogoGeometry.whaleBottom)])
                    context.fill(Path(LogoGeometry.whale(in: art)),
                                 with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: art.minY + art.height * 0.4),
                                                       endPoint: CGPoint(x: 0, y: art.minY + art.height * 0.78)),
                                 style: FillStyle(eoFill: true))
                    for box in LogoGeometry.containers(in: art) {
                        context.fill(Path(roundedRect: box, cornerRadius: box.width * 0.18), with: .color(.white))
                    }
                }
            )
    }
}
