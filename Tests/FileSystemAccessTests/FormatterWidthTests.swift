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

    /// Two parameters, which the count allowance keeps on one line — a line 128 characters wide.
    private static let wideSignature = """
        struct S {
            func handle(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa: Int, bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb: Int) -> Int {
                0
            }
        }

        """

    @Test(.temporaryDirectory)
    func parametersTooWideForOneLineAreSplit() throws {
        try writeSwiftFormat(lineLength: 100)
        #expect(try violationsInWideSignature().count == 1)
    }

    @Test(.temporaryDirectory)
    func parametersThatFitTheWidthStayOnOneLine() throws {
        try writeSwiftFormat(lineLength: 200)
        #expect(try violationsInWideSignature().isEmpty)
    }

    private func violationsInWideSignature() throws -> [StyleViolation] {
        try violations(in: Self.wideSignature, rule: "multiline_parameters")
    }

    private func writeSwiftFormat(lineLength: Int) throws {
        try #"{"version": 1, "lineLength": \#(lineLength)}"#
            .write(to: URL.cwd.appending(path: ".swift-format"), atomically: true, encoding: .utf8)
    }

    private func violationsInSplitCall() throws -> [StyleViolation] {
        try violations(in: Self.splitCall, rule: "multiline_call_arguments")
    }

    private func violations(in source: String, rule: String) throws -> [StyleViolation] {
        let path = URL.cwd.appending(path: "\(UUID().uuidString).swift")
        try source.write(to: path, atomically: true, encoding: .utf8)
        let file = try #require(SwiftLintFile(path: path))
        let configuration = try Configuration(dict: [
            "only_rules": [rule],
            rule: [
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
