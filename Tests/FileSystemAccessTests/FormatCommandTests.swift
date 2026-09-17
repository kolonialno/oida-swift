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

    /// The check answers with the formatter's status. It used to exit on it, which ended the run before the
    /// documents were read and left a markdown finding out of every report on an unformatted tree.
    @Test(.temporaryDirectory)
    func theCheckAnswersWithTheFormattersStatusInsteadOfEndingTheRun() throws {
        try writeSwiftFormat()
        let path = URL.cwd.appending(path: "Messy.swift")
        try "struct Messy  {\n  let  b :  Int = 2\n}\n".write(to: path, atomically: true, encoding: .utf8)
        #expect(try FormatCommand.check(paths: [path.filepath], quiet: true, keepingImportOrder: false) != 0)
    }

    @Test(.temporaryDirectory)
    func theCheckAnswersZeroForAFormattedTree() throws {
        try writeSwiftFormat()
        let path = URL.cwd.appending(path: "Tidy.swift")
        try "struct Tidy {\n    let b: Int = 2\n}\n".write(to: path, atomically: true, encoding: .utf8)
        #expect(try FormatCommand.check(paths: [path.filepath], quiet: true, keepingImportOrder: false) == 0)
    }

    /// swift-format's `NoAccessLevelOnExtensionDeclaration` strands every other modifier when it strips the
    /// access level off an extension that has anything above it, and the result still compiles.
    @Test(.temporaryDirectory)
    func theFormatterIsNotAllowedToStrandAModifier() throws {
        try writeSwiftFormat()
        let source = """
            import UIKit

            public nonisolated extension UIFont {
                var a: Int { 1 }
            }

            """
        let path = URL.cwd.appending(path: "Extension.swift")
        try source.write(to: path, atomically: true, encoding: .utf8)
        try FormatCommand.run(over: [path.filepath], quiet: true, keepingImportOrder: false)
        let formatted = try String(contentsOf: path, encoding: .utf8)
        #expect(formatted.contains("public nonisolated extension UIFont {"))
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
