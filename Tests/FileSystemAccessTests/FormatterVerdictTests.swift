import Foundation
import SwiftLintCore
import TestHelpers
import Testing

@testable import SwiftLintFramework

/// The shape rules ask swift-format whether a line survives before asking for it, so each case runs at a
/// width the formatter breaks and at one it keeps. There is no width in these tests: the number is the
/// formatter's, written to the `.swift-format` it reads.
@Suite(.rulesRegistered, .enabled(if: SwiftFormat.isAvailable))
struct FormatterVerdictTests {
    private static let splitCall = """
        foo(
            aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
            bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
        )

        """

    private static let splitGuard = """
        func f() {
            guard cccccccccccccccccccccccccccccccccccccccccccccc,
                dddddddddddddddddddddddddddddddddddddddddddddddddddd
            else { return }
        }

        """

    private static let oneLineHeader = """
        struct S {
            func handle(eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee: Int, ffffffffffffffffffffffffffffffffffffffffffffff: Int) -> Int {
                0
            }
        }

        """

    @Test(.temporaryDirectory)
    func aJoinTheFormatterWouldBreakIsNotAskedFor() throws {
        try writeSwiftFormat(lineLength: 100)
        #expect(try violations(in: Self.splitCall, rule: "multiline_call_arguments").isEmpty)
    }

    @Test(.temporaryDirectory)
    func aJoinTheFormatterKeepsIsStillAskedFor() throws {
        try writeSwiftFormat(lineLength: 200)
        #expect(try violations(in: Self.splitCall, rule: "multiline_call_arguments").count == 1)
    }

    @Test(.temporaryDirectory)
    func conditionsTheFormatterWouldBreakStaySplit() throws {
        try writeSwiftFormat(lineLength: 100)
        #expect(try violations(in: Self.splitGuard, rule: "multiline_conditions").isEmpty)
    }

    @Test(.temporaryDirectory)
    func conditionsTheFormatterKeepsAreAskedBackOntoOneLine() throws {
        try writeSwiftFormat(lineLength: 200)
        #expect(try violations(in: Self.splitGuard, rule: "multiline_conditions").count == 1)
    }

    @Test(.temporaryDirectory)
    func parametersOnALineTheFormatterWouldBreakAreSplit() throws {
        try writeSwiftFormat(lineLength: 100)
        #expect(try violations(in: Self.oneLineHeader, rule: "multiline_parameters").count == 1)
    }

    @Test(.temporaryDirectory)
    func parametersOnALineTheFormatterKeepsStayThere() throws {
        try writeSwiftFormat(lineLength: 200)
        #expect(try violations(in: Self.oneLineHeader, rule: "multiline_parameters").isEmpty)
    }

    private func writeSwiftFormat(lineLength: Int) throws {
        try #"{"version": 1, "lineLength": \#(lineLength), "indentation": {"spaces": 4}}"#
            .write(to: URL.cwd.appending(path: ".swift-format"), atomically: true, encoding: .utf8)
    }

    private func violations(in source: String, rule: String) throws -> [StyleViolation] {
        let path = URL.cwd.appending(path: "\(UUID().uuidString).swift")
        try source.write(to: path, atomically: true, encoding: .utf8)
        let file = try #require(SwiftLintFile(path: path))
        let configuration = try Configuration(dict: [
            "only_rules": [rule],
            rule: [
                "max_number_of_single_line_parameters": 2,
            ],
        ])
        let storage = RuleStorage()
        return Linter(file: file, configuration: configuration)
            .collect(into: storage)
            .styleViolations(using: storage)
    }
}
