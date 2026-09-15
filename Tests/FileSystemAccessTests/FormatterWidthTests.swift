import Foundation
import TestHelpers
import Testing

@testable import SwiftLintFramework

@Suite(.rulesRegistered)
struct FormatterWidthTests {
    /// Two arguments, so the rule asks for them on one line; joined, the call is 109 characters wide.
    private static let splitCall = """
        foo(
            \(String(repeating: "a", count: 48)),
            \(String(repeating: "b", count: 54))
        )

        """

    @Test(.temporaryDirectory)
    func aJoinTheFormatterWouldBreakIsNotAskedFor() throws {
        try writeSwiftFormat(lineLength: 100)
        #expect(try violationsInSplitCall().isEmpty)
    }

    @Test(.temporaryDirectory)
    func aJoinTheFormatterWouldKeepIsStillAskedFor() throws {
        try writeSwiftFormat(lineLength: 200)
        #expect(try violationsInSplitCall().count == 1)
    }

    @Test(.temporaryDirectory)
    func aTreeWithoutASwiftFormatIsHeldToNoWidth() throws {
        #expect(try violationsInSplitCall().count == 1)
    }

    private func writeSwiftFormat(lineLength: Int) throws {
        try #"{"version": 1, "lineLength": \#(lineLength)}"#
            .write(to: URL.cwd.appending(path: ".swift-format"), atomically: true, encoding: .utf8)
    }

    private func violationsInSplitCall() throws -> [StyleViolation] {
        let path = URL.cwd.appending(path: "\(UUID().uuidString).swift")
        try Self.splitCall.write(to: path, atomically: true, encoding: .utf8)
        let file = try #require(SwiftLintFile(path: path))
        let configuration = try Configuration(dict: [
            "only_rules": ["multiline_call_arguments"],
            "multiline_call_arguments": [
                "max_number_of_single_line_parameters": 2,
                "requires_single_line": true,
            ],
        ])
        let storage = RuleStorage()
        return Linter(file: file, configuration: configuration)
            .collect(into: storage)
            .styleViolations(using: storage)
    }
}
