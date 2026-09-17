import Foundation

/// The swift-format Xcode's Format File runs, found through `xcrun` so the tree and the keystroke cannot
/// disagree; on Linux the toolchain's own, which ships on `PATH`.
public enum SwiftFormat {
    public static var isAvailable: Bool { binary != nil }

    public static let binary: URL? = {
        #if os(macOS)
        let found = output(of: URL(fileURLWithPath: "/usr/bin/xcrun"), arguments: ["--find", "swift-format"])
        #else
        let found = output(of: URL(fileURLWithPath: "/usr/bin/which"), arguments: ["swift-format"])
        #endif
        return found.isEmpty ? nil : URL(fileURLWithPath: found)
    }()

    /// `true` where there is no formatter to ask or the snippet does not parse: nothing then overrules the
    /// rule, so the rule's own answer stands.
    ///
    /// The snippet travels inside as many `do {}` shells as its indentation is deep, because the formatter
    /// puts top-level code at column zero and the width it measures starts there.
    public static func keeps(_ line: String, in snippet: String, indentedBy indentation: Int, at path: URL?) -> Bool {
        guard let binary else {
            return true
        }
        let key = "\(directory(of: path))\u{0}\(indentation)\u{0}\(snippet)"
        if let cached = verdicts[key] {
            return cached
        }
        let depth = indentation / indentationUnit(at: path)
        let wrapped = String(repeating: "do {\n", count: depth) + snippet + "\n" + String(repeating: "}\n", count: depth)
        let verdict = format(wrapped, at: path, with: binary).map { $0.contains(line) } ?? true
        verdicts[key] = verdict
        return verdict
    }

    /// swift-format rules oida turns off for every run.
    ///
    /// `NoAccessLevelOnExtensionDeclaration` strands every other modifier when it strips the access level
    /// off an extension that has anything above it — an import, a declaration, a comment — leaving the
    /// modifier on a line of its own, the declaration indented and its brace orphaned. The result parses,
    /// so a build stays green and only a reader finds it. Reported against swift-format from Xcode 26.
    private static let unsafeRules = ["NoAccessLevelOnExtensionDeclaration"]

    /// The configuration swift-format would use for `path`, with the rules oida turns off applied, as the
    /// JSON string `--configuration` takes.
    ///
    /// `keepingImportOrder` additionally turns off `OrderedImports`: `grouped_imports` orders imports by
    /// origin and `OrderedImports` sorts that ordering away, so the tool invoking the formatter is the one
    /// that has to settle it.
    ///
    /// The effective configuration is read from the formatter rather than from the file, so a repository's
    /// own keys survive whatever this turns off.
    public static func configuration(for path: String, keepingImportOrder: Bool) -> String? {
        guard let binary else {
            return nil
        }
        let key = "\(configurationRoot(for: path))\u{0}\(keepingImportOrder)"
        if let cached = configurations[key] {
            return cached
        }
        let dumped = output(
            of: binary,
            arguments: ["dump-configuration", "--effective"],
            from: configurationRoot(for: path)
        )
        guard let data = dumped.data(using: .utf8),
              var configuration = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        var rules = configuration["rules"] as? [String: Any] ?? [:]
        for rule in unsafeRules {
            rules[rule] = false
        }
        if keepingImportOrder {
            rules["OrderedImports"] = false
        }
        configuration["rules"] = rules
        guard let merged = try? JSONSerialization.data(withJSONObject: configuration),
              let json = String(data: merged, encoding: .utf8) else {
            return nil
        }
        configurations[key] = json
        return json
    }

    /// The nearest ancestor holding a `.swift-format`, which is what the formatter's own discovery finds —
    /// so paths sharing one are dumped once rather than once apiece.
    private static func configurationRoot(for path: String) -> String {
        var current = URL(fileURLWithPath: path).deletingLastPathComponent()
        while current.pathComponents.count > 1 {
            if FileManager.default.fileExists(atPath: current.appending(path: ".swift-format").filepath) {
                return current.filepath
            }
            current = current.deletingLastPathComponent()
        }
        return current.filepath
    }

    private static let verdicts = Memo<Bool>()
    private static let units = Memo<Int>()
    private static let configurations = Memo<String>()

    /// Read by formatting one block and measuring what comes back, so the formatter's setting is never
    /// read from a file this tool would then have an opinion about.
    private static func indentationUnit(at path: URL?) -> Int {
        let key = directory(of: path)
        if let cached = units[key] {
            return cached
        }
        let unit = binary
            .flatMap { format("do {\nlet x = 1\n}", at: path, with: $0) }
            .flatMap { $0.split(separator: "\n").dropFirst().first }
            .map { $0.prefix(while: { $0 == " " }).count }
            .flatMap { $0 > 0 ? $0 : nil } ?? 4
        units[key] = unit
        return unit
    }

    private static func directory(of path: URL?) -> String {
        path?.deletingLastPathComponent().filepath ?? ""
    }

    private static func format(_ source: String, at path: URL?, with binary: URL) -> String? {
        let process = Process()
        process.executableURL = binary
        var arguments = ["format", "-"]
        if let path {
            arguments += ["--assume-filename", path.filepath]
        }
        process.arguments = arguments
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        input.fileHandleForWriting.write(Data(source.utf8))
        input.fileHandleForWriting.closeFile()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }
        return String(bytes: data, encoding: .utf8)
    }

    private static func output(of binary: URL, arguments: [String], from directory: String? = nil) -> String {
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        if let directory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(bytes: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private final class Memo<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Value] = [:]

    subscript(key: String) -> Value? {
        get { lock.withLock { storage[key] } }
        set { lock.withLock { storage[key] = newValue } }
    }
}
