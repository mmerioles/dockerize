import Foundation

/// The Dockerize roadmap: the Docker commands and concepts an everyday engineer
/// needs, from the first `docker run` to Compose, registries and debugging,
/// ordered so each lesson builds on the last.
///
/// Conventions every lesson follows:
/// - Everything a learner creates is named with a `dz-` prefix (containers,
///   images, volumes, networks, Compose projects), so "Clean Up Lab Resources"
///   can remove it without touching anything else on the engine.
/// - Images are pinned to the small tags in `Img`, so each is pulled once.
public enum Curriculum {
    public static let categories: [Category] = [
        gettingStarted,
        containers,
        images,
        data,
        networking,
        compose,
        shipping,
        operations,
    ]

    public static var lessons: [Lesson] { categories.flatMap(\.lessons) }

    public static func lesson(_ id: String) -> Lesson? {
        lessons.first { $0.id == id }
    }

    public static func category(of lesson: Lesson) -> Category? {
        categories.first { $0.lessons.contains(lesson) }
    }

    public static func next(after lesson: Lesson) -> Lesson? {
        let all = lessons
        guard let i = all.firstIndex(of: lesson), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    public static func previous(before lesson: Lesson) -> Lesson? {
        let all = lessons
        guard let i = all.firstIndex(of: lesson), i > 0 else { return nil }
        return all[i - 1]
    }

    /// Every reference row across the curriculum, for the cheat sheet.
    public static var cheatSheet: [(lesson: Lesson, option: CommandOption)] {
        lessons.flatMap { lesson in lesson.reference.map { (lesson, $0) } }
    }

    /// The prefix for everything lessons create.
    public static let prefix = "dz-"
}

/// Image tags used by the lessons. Small, multi-arch (Apple silicon and Intel).
public enum Img {
    public static let hello = "hello-world:latest"
    public static let alpine = "alpine:3.20"
    public static let busybox = "busybox:1.36"
    public static let nginx = "nginx:1.27-alpine"
    public static let redis = "redis:7-alpine"
    public static let python = "python:3.12-alpine"
    public static let registry = "registry:2"
}

// Short names keep the lesson files readable.
typealias N = Diagram.Node
typealias E = Diagram.Edge
typealias G = Diagram.Group
typealias S = LessonSection
typealias O = CommandOption
typealias F = Seed.File
