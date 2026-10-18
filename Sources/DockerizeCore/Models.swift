import Foundation

// MARK: - Curriculum

/// A top-level roadmap category, e.g. "Images & Dockerfiles".
public struct Category: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let icon: String          // SF Symbol name
    public let blurb: String
    public let lessons: [Lesson]

    public init(id: String, title: String, icon: String, blurb: String, lessons: [Lesson]) {
        self.id = id
        self.title = title
        self.icon = icon
        self.blurb = blurb
        self.lessons = lessons
    }

    public static func == (lhs: Category, rhs: Category) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// One lesson: an explanation, a diagram, a command reference and missions
/// the learner completes in their own shell.
public struct Lesson: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Commands covered, shown as chips (e.g. ["docker run"]).
    public let commands: [String]
    /// Concepts and commands shown on the roadmap page. Defaults to `commands`.
    public let topics: [String]
    public let summary: String
    public let sections: [LessonSection]
    public let reference: [CommandOption]
    /// Where Docker on a Mac differs from Docker on Linux (the VM, file sharing, networking).
    public let macNote: String?
    /// Images the lesson uses. The app offers to pull them before you start.
    public let images: [String]
    public let diagram: Diagram
    public let seed: Seed
    public let missions: [Mission]

    public init(
        id: String, title: String, commands: [String], topics: [String]? = nil, summary: String,
        sections: [LessonSection], reference: [CommandOption] = [], macNote: String? = nil,
        images: [String] = [], diagram: Diagram, seed: Seed = Seed(), missions: [Mission]
    ) {
        self.id = id
        self.title = title
        self.commands = commands
        self.topics = topics ?? commands
        self.summary = summary
        self.sections = sections
        self.reference = reference
        self.macNote = macNote
        self.images = images
        self.diagram = diagram
        self.seed = seed
        self.missions = missions
    }

    /// Whether any mission needs to look at the Docker engine's state.
    public var usesDockerState: Bool { missions.contains { $0.check.needsDocker } }

    public static func == (lhs: Lesson, rhs: Lesson) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public struct LessonSection: Hashable, Sendable {
    public let heading: String
    /// Inline Markdown (`code`, **bold**, _italic_). Blank lines separate paragraphs.
    public let body: String
    public let example: Example?

    public init(_ heading: String, _ body: String, example: Example? = nil) {
        self.heading = heading
        self.body = body
        self.example = example
    }
}

public struct Example: Hashable, Sendable {
    public let command: String
    public let output: String?

    public init(_ command: String, output: String? = nil) {
        self.command = command
        self.output = output
    }
}

public struct CommandOption: Hashable, Sendable {
    public let syntax: String
    public let meaning: String

    public init(_ syntax: String, _ meaning: String) {
        self.syntax = syntax
        self.meaning = meaning
    }
}

// MARK: - Workspace seed

/// Files and folders created in a lesson's workspace before the learner starts.
public struct Seed: Hashable, Sendable {
    public struct File: Hashable, Sendable {
        public let path: String
        public let contents: String
        public let mode: Int?    // POSIX permissions, e.g. 0o644

        public init(_ path: String, _ contents: String, mode: Int? = nil) {
            self.path = path
            self.contents = contents
            self.mode = mode
        }
    }

    public let directories: [String]
    public let files: [File]

    public init(directories: [String] = [], files: [File] = []) {
        self.directories = directories
        self.files = files
    }
}

// MARK: - Missions

public struct Mission: Hashable, Sendable {
    public let title: String
    public let hint: String
    public let solution: String
    public let check: Check

    public init(_ title: String, hint: String, solution: String, check: Check) {
        self.title = title
        self.hint = hint
        self.solution = solution
        self.check = check
    }
}

/// What has to be true for a mission to count as done. File paths are relative
/// to the lesson workspace. Docker checks look at the engine's live state.
public indirect enum Check: Hashable, Sendable {
    /// A command typed in this lesson matches the regex.
    case ran(String)
    /// Like `.ran`, but the command must also have exited with status 0.
    case ranOK(String)
    /// The command matched and was run in a directory ending with this path.
    case ranIn(String, String)
    case exists(String, Kind)
    case missing(String)
    /// The file exists and contains the text.
    case contains(String, String)
    /// The file exists and its contents match the regex.
    case matches(String, String)

    // Docker engine state
    /// A container with this exact name exists and is in the given state.
    case container(String, ContainerState)
    /// An image with this reference exists locally. A reference without a tag means `:latest`.
    case image(String)
    case volume(String)
    case network(String)
    /// The container is attached to the network.
    case onNetwork(String, String)
    /// The container publishes this port on the host.
    case publishes(String, Int)
    /// One of the container's mounts (volume name or host path) contains this text.
    case mounts(String, String)
    /// A container with this label key and value exists (running or not).
    case labeled(String, String)
    /// A running container belongs to this Compose project and service.
    case composeService(String, String)

    case all([Check])
    case any([Check])
    case not(Check)

    public enum Kind: Hashable, Sendable { case file, directory, any }
    public enum ContainerState: Hashable, Sendable { case exists, running, stopped }

    public var needsDocker: Bool {
        switch self {
        case .ran, .ranOK, .ranIn, .exists, .missing, .contains, .matches: return false
        case .container, .image, .volume, .network, .onNetwork, .publishes, .mounts, .labeled, .composeService: return true
        case .all(let c), .any(let c): return c.contains { $0.needsDocker }
        case .not(let c): return c.needsDocker
        }
    }
}

// MARK: - Diagrams

/// A small architecture-style diagram: nodes sit on a grid, groups draw
/// labelled boundaries around nodes, and edges connect nodes.
public struct Diagram: Hashable, Sendable {
    public let title: String
    public let caption: String
    public let nodes: [Node]
    public let groups: [Group]
    public let edges: [Edge]

    public init(_ title: String, caption: String, nodes: [Node], groups: [Group] = [], edges: [Edge]) {
        self.title = title
        self.caption = caption
        self.nodes = nodes
        self.groups = groups
        self.edges = edges
    }

    public var columns: Int { (nodes.map(\.col).max() ?? 0) + 1 }
    public var rows: Int { (nodes.map(\.row).max() ?? 0) + 1 }
    public func node(_ id: String) -> Node? { nodes.first { $0.id == id } }

    public struct Node: Hashable, Sendable {
        public let id: String
        public let label: String
        public let detail: String?
        public let icon: String
        public let kind: Kind
        public let col: Int
        public let row: Int

        public init(_ id: String, _ label: String, icon: String, _ kind: Kind, at col: Int, _ row: Int, detail: String? = nil) {
            self.id = id
            self.label = label
            self.detail = detail
            self.icon = icon
            self.kind = kind
            self.col = col
            self.row = row
        }

        public enum Kind: String, Hashable, Sendable {
            case actor      // you, a developer
            case cli        // the docker CLI, compose, a shell
            case daemon     // dockerd, containerd, BuildKit
            case image      // an image or a layer
            case container  // a running or stopped container
            case registry   // Docker Hub, a private registry
            case storage    // volumes, bind mounts, the host filesystem
            case network    // a Docker network, a port, the internet
            case file       // a Dockerfile, compose.yaml, source code
            case host       // the Linux VM, the kernel, the Mac
        }
    }

    public struct Group: Hashable, Sendable {
        public let label: String
        public let members: [String]

        public init(_ label: String, _ members: [String]) {
            self.label = label
            self.members = members
        }
    }

    public struct Edge: Hashable, Sendable {
        public let from: String
        public let to: String
        public let label: String?
        public let dashed: Bool
        /// Draw as a U-turn under both nodes (for loop-backs on the same row).
        public let loopBack: Bool

        public init(_ from: String, _ to: String, _ label: String? = nil, dashed: Bool = false, loopBack: Bool = false) {
            self.from = from
            self.to = to
            self.label = label
            self.dashed = dashed
            self.loopBack = loopBack
        }
    }
}
