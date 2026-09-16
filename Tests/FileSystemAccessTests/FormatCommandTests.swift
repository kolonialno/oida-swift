import Foundation
import SwiftLintCore
import TestHelpers
import Testing

@testable import SwiftLintFramework

/// `grouped_imports` orders imports by origin; swift-format's `OrderedImports` sorts them alphabetically.
/// Both run under `--fix --format`, so the formatter has to be told to leave the order alone.
@Suite(.rulesRegistered, .enabled(if: SwiftFormat.isAvailable))
struct FormatCommandTests {
    private static let grouped = """
        import SwiftUI

        import DemoCore

        """

    @Test(.temporaryDirectory)
    func theFormatterLeavesGroupedImportsAlone() throws {
        try writeSwiftFormat()
        let path = try write(Self.grouped)
        try FormatCommand.run(over: [path.filepath], quiet: true, keepingImportOrder: true)
        #expect(try String(contentsOf: path, encoding: .utf8) == Self.grouped)
    }

    @Test(.temporaryDirectory)
    func theFormatterStillSortsImportsWhereNoRuleOrdersThem() throws {
        try writeSwiftFormat()
        let path = try write(Self.grouped)
        try FormatCommand.run(over: [path.filepath], quiet: true, keepingImportOrder: false)
        #expect(try String(contentsOf: path, encoding: .utf8) == "import DemoCore\nimport SwiftUI\n")
    }

    @Test(.temporaryDirectory)
    func theRepositorysOwnFormatterSettingsSurvive() throws {
        try #"{"version": 1, "indentation": {"spaces": 8}}"#
            .write(to: URL.cwd.appending(path: ".swift-format"), atomically: true, encoding: .utf8)
        let path = try write("struct S {\nvar a: Int { 1 }\n}\n")
        try FormatCommand.run(over: [path.filepath], quiet: true, keepingImportOrder: true)
        #expect(try String(contentsOf: path, encoding: .utf8).contains("\n        var a: Int { 1 }"))
    }

    private func writeSwiftFormat() throws {
        try #"{"version": 1, "indentation": {"spaces": 4}}"#
            .write(to: URL.cwd.appending(path: ".swift-format"), atomically: true, encoding: .utf8)
    }

    private func write(_ source: String) throws -> URL {
        let path = URL.cwd.appending(path: "Imports.swift")
        try source.write(to: path, atomically: true, encoding: .utf8)
        return path
    }
}
