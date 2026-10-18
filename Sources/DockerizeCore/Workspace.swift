import Foundation

/// One command the learner ran, as logged by the shell's PROMPT_COMMAND hook.
public struct CommandRecord: Hashable, Sendable {
    public let status: Int32
    public let directory: String
    public let command: String

    public init(status: Int32, directory: String, command: String) {
        self.status = status
        self.directory = directory
        self.command = command
    }

    /// Parses one `status<TAB>pwd<TAB>command` line from the log.
    public init?(logLine: String) {
        let parts = logLine.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let status = Int32(parts[0]) else { return nil }
        self.status = status
        self.directory = String(parts[1])
        self.command = String(parts[2]).trimmingCharacters(in: .whitespaces)
    }
}

/// Manages the folder the embedded shell lives in. The shell's `$HOME` is a
/// sandbox, but `docker` still uses your real Docker config and contexts.
///
/// Layout (default root is `~/Library/Application Support/Dockerize`):
///
///     Dockerize/
///       dockerizerc        generated bash profile
///       commands.log     every command typed: status, pwd, command
///       home/            $HOME for the shell
///         <lesson-id>/   one workspace per lesson, seeded with files
public final class Workspace: @unchecked Sendable {
    public let root: URL
    public var home: URL { root.appendingPathComponent("home", isDirectory: true) }
    public var rcFile: URL { root.appendingPathComponent("dockerizerc") }
    public var logFile: URL { root.appendingPathComponent("commands.log") }

    private let fm = FileManager.default
    private var logOffset: UInt64 = 0

    public init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.root = support.appendingPathComponent("Dockerize", isDirectory: true)
        }
    }

    /// Creates the folders and profile, and skips any log lines written before launch.
    public func prepare() throws {
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        try Self.rcContents.write(to: rcFile, atomically: true, encoding: .utf8)
        if !fm.fileExists(atPath: logFile.path) {
            fm.createFile(atPath: logFile.path, contents: nil)
        }
        logOffset = (try? fm.attributesOfItem(atPath: logFile.path)[.size] as? UInt64) ?? 0
    }

    public func directory(for lesson: Lesson) -> URL {
        home.appendingPathComponent(lesson.id, isDirectory: true)
    }

    /// Seeds the lesson's workspace the first time it is opened.
    @discardableResult
    public func ensure(_ lesson: Lesson) throws -> URL {
        let dir = directory(for: lesson)
        if !fm.fileExists(atPath: dir.path) {
            try seed(lesson, into: dir)
        }
        return dir
    }

    /// Deletes everything in the lesson's workspace and seeds it again.
    public func reset(_ lesson: Lesson) throws {
        let dir = directory(for: lesson)
        if fm.fileExists(atPath: dir.path) {
            try makeWritable(dir)
            try fm.removeItem(at: dir)
        }
        try seed(lesson, into: dir)
    }

    private func seed(_ lesson: Lesson, into dir: URL) throws {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for path in lesson.seed.directories {
            try fm.createDirectory(at: dir.appendingPathComponent(path, isDirectory: true), withIntermediateDirectories: true)
        }
        for file in lesson.seed.files {
            let url = dir.appendingPathComponent(file.path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
            if let mode = file.mode {
                try fm.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
            }
        }
    }

    /// Containers writing to bind mounts can leave read-only files behind; fix
    /// them so a reset can delete them.
    private func makeWritable(_ dir: URL) throws {
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
        guard let walker = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for case let url as URL in walker {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            try? fm.setAttributes([.posixPermissions: isDir ? 0o755 : 0o644], ofItemAtPath: url.path)
        }
    }

    /// Returns commands logged since the last call.
    public func readNewCommands() -> [CommandRecord] {
        guard let handle = try? FileHandle(forReadingFrom: logFile) else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        if size < logOffset { logOffset = 0 }   // log was truncated
        guard size > logOffset else { return [] }
        try? handle.seek(toOffset: logOffset)
        guard let data = try? handle.readToEnd() else { return [] }
        // Only consume complete lines.
        guard let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return [] }
        let complete = data[data.startIndex...lastNewline]
        logOffset += UInt64(complete.count)
        return String(decoding: complete, as: UTF8.self)
            .split(separator: "\n")
            .compactMap { CommandRecord(logLine: String($0)) }
    }

    /// PATH with the usual places Docker installs its CLI added.
    public static func searchPath(_ inherited: String?) -> String {
        var path = inherited ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let realHome = NSHomeDirectory()
        let extras = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(realHome)/.orbstack/bin",
            "\(realHome)/.docker/bin",
            "/Applications/Docker.app/Contents/Resources/bin",
            "\(realHome)/.rd/bin",   // Rancher Desktop
        ]
        for extra in extras.reversed() where !path.split(separator: ":").contains(Substring(extra)) {
            path = "\(extra):\(path)"
        }
        return path
    }

    /// Environment for the embedded bash process.
    public func environment(startIn dir: URL) -> [String] {
        let inherited = ProcessInfo.processInfo.environment
        let user = inherited["USER"] ?? NSUserName()
        let realHome = NSHomeDirectory()
        var env = [
            "TERM=xterm-256color",
            "COLORTERM=truecolor",
            "LANG=\(inherited["LANG"] ?? "en_US.UTF-8")",
            "HOME=\(home.path)",
            "PATH=\(Self.searchPath(inherited["PATH"]))",
            "USER=\(user)",
            "LOGNAME=\(user)",
            "SHELL=/bin/bash",
            "BASH_SILENCE_DEPRECATION_WARNING=1",
            "TMPDIR=\(inherited["TMPDIR"] ?? NSTemporaryDirectory())",
            // $HOME is the sandbox, so point docker at your real config, contexts and logins.
            "DOCKER_CONFIG=\(inherited["DOCKER_CONFIG"] ?? realHome + "/.docker")",
            "DOCKER_CLI_HINTS=false",
            "DOCKERIZE_LOG=\(logFile.path)",
            "DOCKERIZE_START_DIR=\(dir.path)",
        ]
        for key in ["DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_CERT_PATH", "DOCKER_TLS_VERIFY", "SSH_AUTH_SOCK"] {
            if let value = inherited[key] { env.append("\(key)=\(value)") }
        }
        return env
    }

    public var shellArguments: [String] { ["--rcfile", rcFile.path, "-i"] }

    /// The generated bash profile. Works with macOS's bash 3.2.
    ///
    /// After each command, `__dockerize_prompt` appends `status<TAB>pwd<TAB>command`
    /// to $DOCKERIZE_LOG so the app can check missions. Commands that start with
    /// a space are left out of history (HISTCONTROL=ignorespace), which is how
    /// the app sends its own `cd` without it counting as the learner's work.
    public static let rcContents = #"""
    # Generated by Dockerize. Edits are overwritten each launch.
    export BASH_SILENCE_DEPRECATION_WARNING=1
    export HISTFILE="$HOME/.bash_history"
    export HISTCONTROL=ignorespace
    export HISTSIZE=5000
    export HISTFILESIZE=5000
    export CLICOLOR=1
    export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd
    shopt -s histappend

    __dockerize_last="__init__"
    __dockerize_prompt() {
      local status=$?
      builtin history -a
      local entry num cmd
      entry=$(HISTTIMEFORMAT= builtin history 1)
      num=$(printf '%s\n' "$entry" | awk 'NR==1 {print $1}')
      if [ "$__dockerize_last" = "__init__" ]; then
        __dockerize_last="$num"
      elif [ -n "$num" ] && [ "$num" != "$__dockerize_last" ]; then
        __dockerize_last="$num"
        cmd=$(printf '%s\n' "$entry" | sed -E '1s/^ *[0-9]+\*? *//' | tr '\n\t' '  ')
        printf '%s\t%s\t%s\n' "$status" "$PWD" "$cmd" >> "$DOCKERIZE_LOG"
      fi
    }
    PROMPT_COMMAND=__dockerize_prompt

    PS1='\[\e[38;5;39m\]dockerize\[\e[0m\] \[\e[38;5;111m\]\w\[\e[0m\] \$ '

    # Short names for the commands you'll type most.
    alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'

    # Your own aliases and functions live in the sandbox's ~/.bashrc.
    [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"

    cd "$DOCKERIZE_START_DIR" 2>/dev/null || cd ~
    """#
}
