import SwiftUI

/// The Dockerize mark: three shipping containers stacked 2 + 1.
enum LogoGeometry {
    /// Container rectangles inside `rect`, in AppKit coordinates (origin bottom-left).
    static func boxes(in rect: CGRect) -> [CGRect] {
        let gap = rect.width * 0.06
        let w = (rect.width - gap) / 2
        let h = (rect.height - gap) / 2
        return [
            CGRect(x: rect.minX, y: rect.minY, width: w, height: h),
            CGRect(x: rect.minX + w + gap, y: rect.minY, width: w, height: h),
            CGRect(x: rect.midX - w / 2, y: rect.minY + h + gap, width: w, height: h),
        ]
    }
}

/// The mark as a SwiftUI view, for the sidebar.
struct LogoMark: View {
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22)
            .fill(LinearGradient(colors: [Color(hex: 0x2496ED), Color(hex: 0x1060FF)], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(
                Canvas { context, canvasSize in
                    let inner = CGRect(origin: .zero, size: canvasSize).insetBy(dx: size * 0.2, dy: size * 0.24)
                    for box in LogoGeometry.boxes(in: inner) {
                        // Flip: Canvas has its origin at the top-left.
                        let flipped = CGRect(x: box.minX, y: canvasSize.height - box.maxY, width: box.width, height: box.height)
                        context.fill(Path(roundedRect: flipped, cornerRadius: size * 0.04), with: .color(.white))
                    }
                }
            )
    }
}
