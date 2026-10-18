import SwiftUI
import DockerizeCore

/// Every reference row from every lesson in one searchable page: the
/// commands you reach for day to day, grouped by roadmap section.
struct CheatSheetView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""

    private var groups: [(category: DockerizeCore.Category, rows: [(lesson: Lesson, option: CommandOption)])] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return Curriculum.categories.compactMap { category in
            let rows = category.lessons.flatMap { lesson in
                lesson.reference.map { (lesson: lesson, option: $0) }
            }.filter { row in
                q.isEmpty
                    || row.option.syntax.lowercased().contains(q)
                    || row.option.meaning.lowercased().contains(q)
                    || row.lesson.title.lowercased().contains(q)
            }
            return rows.isEmpty ? nil : (category, rows)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cheat sheet").font(.system(size: 26, weight: .semibold)).foregroundStyle(Theme.textStrong)
                    Text("Every command and flag from the lessons, in one place. Click a command to type it into the shell.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                }
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textFaint)
                    TextField("Search commands, flags or descriptions (e.g. port, prune, -v)", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.borderStrong))
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 18)
            Divider().overlay(Theme.border)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if groups.isEmpty {
                        Text("Nothing matches \"\(query)\".")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textFaint)
                    }
                    ForEach(groups, id: \.category.id) { group in
                        section(group.category, group.rows)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: 1000, alignment: .leading)
            }
        }
        .background(Theme.page)
    }

    private func section(_ category: DockerizeCore.Category, _ rows: [(lesson: Lesson, option: CommandOption)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(category.title, systemImage: category.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textStrong)
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                        CheatRow(lesson: row.lesson, option: row.option, first: i == 0)
                    }
                }
            }
        }
    }
}

private struct CheatRow: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    let option: CommandOption
    let first: Bool
    @State private var hover = false

    /// Rows like "Ctrl+P Ctrl+Q" or "FROM image" aren't shell commands.
    private var isCommand: Bool { option.syntax.hasPrefix("docker") || option.syntax.hasPrefix("curl") }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Button {
                if isCommand { model.terminal.type(option.syntax) }
            } label: {
                Text(option.syntax)
                    .font(Theme.mono)
                    .foregroundStyle(isCommand && hover ? Theme.action : Theme.textStrong)
                    .multilineTextAlignment(.leading)
                    .frame(width: 330, alignment: .leading)
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .help(isCommand ? "Type into the shell" : "")
            Text(option.meaning)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(lesson.title) { model.open(lesson) }
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.action)
                .lineLimit(1)
                .help("Open the lesson")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { if !first { Divider().overlay(Theme.border) } }
    }
}
