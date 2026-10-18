import AppKit
import SwiftUI

/// White surface with a thin border, the basic Helios container.
struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

struct CardHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textStrong)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Theme.textFaint)
                }
            }
            Spacer()
            trailing
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

enum BadgeTone { case neutral, action, success, highlight, warning }

struct Badge: View {
    let text: String
    var tone: BadgeTone = .neutral
    var icon: String?
    var mono = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(mono ? Theme.monoSmall : .system(size: 11.5, weight: .medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(colors.fg)
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var colors: (fg: Color, bg: Color) {
        switch tone {
        case .neutral: return (Theme.text, Color(hex: 0xF1F2F3))
        case .action: return (Theme.action, Theme.actionSurface)
        case .success: return (Theme.success, Theme.successSurface)
        case .highlight: return (Theme.highlight, Theme.highlightSurface)
        case .warning: return (Theme.warning, Theme.warningSurface)
        }
    }
}

struct ProgressBar: View {
    let value: Double
    var tint: Color = Theme.success
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0xEBECEE))
                Capsule().fill(tint).frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

/// Inline Markdown with `code` spans styled like Helios inline code.
struct RichText: View {
    let markdown: String
    var size: CGFloat = 14

    var body: some View {
        Text(Self.attributed(markdown, size: size))
            .lineSpacing(4)
            .foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    static func attributed(_ markdown: String, size: CGFloat) -> AttributedString {
        var text = (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
        text.font = .system(size: size)
        for run in text.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.code) {
                text[run.range].font = .system(size: size - 1, design: .monospaced)
                text[run.range].foregroundColor = Theme.highlight
                text[run.range].backgroundColor = Theme.highlightSurface
            } else if intent.contains(.stronglyEmphasized) {
                text[run.range].font = .system(size: size, weight: .semibold)
                text[run.range].foregroundColor = Theme.textStrong
            } else if intent.contains(.emphasized) {
                text[run.range].font = .system(size: size).italic()
            }
        }
        return text
    }
}

/// Dark code block for examples, with Copy and (for one-liners) Try it.
struct CodeBlock: View {
    let command: String
    var output: String?
    var onTry: ((String) -> Void)?

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text("$").foregroundStyle(Theme.brand)
                Text(command)
                    .foregroundStyle(Theme.codeText)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    if let onTry, !command.contains("\n") {
                        CodeButton(label: "Try it", icon: "terminal") { onTry(command) }
                            .help("Type this into your shell (you press Return)")
                    }
                    CodeButton(label: copied ? "Copied" : "Copy", icon: copied ? "checkmark" : "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                    }
                }
            }
            .font(Theme.mono)
            .padding(14)

            if let output {
                Divider().overlay(Color.white.opacity(0.08))
                Text(output)
                    .font(Theme.monoSmall)
                    .foregroundStyle(Color(hex: 0xA0A4AE))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
        }
        .background(Theme.code)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct CodeButton: View {
    let label: String
    let icon: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .foregroundStyle(Color(hex: 0xDEDFE3))
                .background(Color.white.opacity(hover ? 0.16 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Primary (filled blue) and secondary (outlined) Helios buttons.
struct HeliosButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, tertiary }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, kind == .tertiary ? 4 : 12)
            .padding(.vertical, 7)
            .foregroundStyle(fg)
            .background(bg.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(kind == .secondary ? Theme.borderStrong : .clear)
            )
            .contentShape(Rectangle())
    }

    private var fg: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return Theme.textStrong
        case .tertiary: return Theme.action
        }
    }

    private var bg: Color {
        switch kind {
        case .primary: return Theme.action
        case .secondary: return Color(hex: 0xFAFAFA)
        case .tertiary: return .clear
        }
    }
}

extension ButtonStyle where Self == HeliosButtonStyle {
    static var primary: HeliosButtonStyle { HeliosButtonStyle(kind: .primary) }
    static var secondary: HeliosButtonStyle { HeliosButtonStyle(kind: .secondary) }
    static var tertiary: HeliosButtonStyle { HeliosButtonStyle(kind: .tertiary) }
}

/// Helios inline alert, used for macOS notes.
struct InlineAlert: View {
    let title: String
    let message: String
    var icon = "apple.logo"
    var tone: BadgeTone = .highlight

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(fg)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textStrong)
                RichText(markdown: message, size: 13)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(border))
    }

    private var fg: Color { tone == .warning ? Theme.warning : Theme.highlight }
    private var bg: Color { tone == .warning ? Theme.warningSurface : Theme.highlightSurface }
    private var border: Color { tone == .warning ? Theme.warningBorder : Color(hex: 0xE4CCFA) }
}
