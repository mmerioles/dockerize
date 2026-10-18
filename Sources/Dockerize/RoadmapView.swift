import SwiftUI
import DockerizeCore

/// The whole curriculum on one page, laid out like roadmap.sh: a vertical
/// spine of lessons grouped under section headings, with each lesson's topics
/// branching off to alternating sides.
struct RoadmapView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let columns = geo.size.width > 1120 ? 3 : 2
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 28)
                    spine(columns: columns)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.page)
    }

    private var header: some View {
        let p = model.overallProgress
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Roadmap")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.textStrong)
                    Text("Everything an everyday engineer needs to be comfortable with Docker, from the first docker run to Compose, registries and debugging. Work top to bottom, or jump to any topic.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: 640, alignment: .leading)
                }
                Spacer()
                Button { model.open(model.continueLesson) } label: {
                    HStack(spacing: 6) { Text("Continue: \(model.continueLesson.title)"); Image(systemName: "arrow.right") }
                }
                .buttonStyle(.primary)
            }
            HStack(spacing: 18) {
                LegendItem(fill: Theme.roadmapNode, label: "Lesson")
                LegendItem(fill: Color(hex: 0xFFF3B0), label: "Topic")
                HStack(spacing: 5) {
                    Image(systemName: "circle.lefthalf.filled").foregroundStyle(Theme.warning)
                    Text("In progress")
                }
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                    Text("Done")
                }
                Spacer()
                Text("\(p.done) of \(p.total) missions").foregroundStyle(Theme.textFaint)
                ProgressBar(value: Double(p.done) / Double(max(p.total, 1))).frame(width: 140)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.text)
        }
    }

    private func spine(columns: Int) -> some View {
        VStack(spacing: 0) {
            // Title on the spine, like the top of a roadmap.sh chart.
            VStack(spacing: 6) {
                DottedLine(axis: .vertical).frame(width: 2, height: 36)
                Text("Docker")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.textStrong)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Theme.page)
            }
            .padding(.bottom, 14)

            ForEach(Curriculum.categories) { category in
                SectionHeading(category: category)
                ForEach(category.lessons) { lesson in
                    let index = Curriculum.lessons.firstIndex(of: lesson) ?? 0
                    LessonRow(lesson: lesson, topicsOnLeft: index % 2 == 0, columns: columns)
                }
            }
        }
        .background(alignment: .top) {
            Rectangle().fill(Theme.action.opacity(0.75)).frame(width: 2)
                .padding(.top, 36)
                .padding(.bottom, 35)
        }
    }
}

private struct SectionHeading: View {
    @EnvironmentObject var model: AppModel
    let category: DockerizeCore.Category

    var body: some View {
        let p = model.progress(category)
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: category.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.action)
                Text(category.title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.textStrong)
                if p.done == p.total {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                }
            }
            Text(category.blurb)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.page)
        .padding(.top, 30)
        .padding(.bottom, 14)
    }
}

private struct LessonRow: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    let topicsOnLeft: Bool
    let columns: Int

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if topicsOnLeft { branch } else { Color.clear }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            LessonNode(lesson: lesson)

            Group {
                if topicsOnLeft { Color.clear } else { branch }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }

    private var branch: some View {
        HStack(spacing: 0) {
            if !topicsOnLeft { DottedLine(axis: .horizontal).frame(width: 44, height: 2) }
            TopicGrid(lesson: lesson, columns: columns)
            if topicsOnLeft { DottedLine(axis: .horizontal).frame(width: 44, height: 2) }
        }
    }
}

private struct LessonNode: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    @State private var hover = false

    var body: some View {
        let done = model.doneCount(lesson)
        let total = lesson.missions.count
        Button { model.open(lesson) } label: {
            HStack(spacing: 8) {
                Text(lesson.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textStrong)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .frame(width: 236, height: 46)
            .background(Theme.roadmapNode)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.textStrong, lineWidth: 2))
            .overlay(alignment: .topTrailing) { status(done: done, total: total) }
            .shadow(color: .black.opacity(hover ? 0.18 : 0.0), radius: 6, y: 3)
            .offset(y: hover ? -1 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
        .help("\(lesson.summary)\n\n\(done)/\(total) missions done")
    }

    @ViewBuilder
    private func status(done: Int, total: Int) -> some View {
        if done == total {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(.white, Theme.success)
                .offset(x: 8, y: -8)
        } else if done > 0 {
            Text("\(done)/\(total)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Theme.warning)
                .clipShape(Capsule())
                .offset(x: 8, y: -8)
        }
    }
}

private struct TopicGrid: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    let columns: Int

    var body: some View {
        let done = model.isComplete(lesson)
        let count = min(columns, lesson.topics.count)
        let grid = Array(repeating: GridItem(.fixed(122), spacing: 6), count: max(count, 1))
        LazyVGrid(columns: grid, spacing: 6) {
            ForEach(lesson.topics, id: \.self) { topic in
                Button { model.open(lesson) } label: {
                    HStack(spacing: 4) {
                        if done {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.success)
                        }
                        Text(topic)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(done ? Theme.textFaint : Theme.textStrong)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 6)
                    .frame(width: 122, height: 34)
                    .background(done ? Theme.successSurface : Color(hex: 0xFFF3B0))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(done ? Theme.successBorder : Theme.textStrong.opacity(0.85), lineWidth: 1.3)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .fixedSize()
    }
}

private struct DottedLine: View {
    enum Axis { case horizontal, vertical }
    let axis: Axis

    var body: some View {
        GeometryReader { geo in
            Path { p in
                if axis == .horizontal {
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                } else {
                    p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                }
            }
            .stroke(Theme.action, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 5]))
        }
    }
}

private struct LegendItem: View {
    let fill: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.textStrong, lineWidth: 1))
                .frame(width: 14, height: 10)
            Text(label)
        }
    }
}
