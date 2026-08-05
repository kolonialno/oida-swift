import Foundation
import SwiftLintCore
import TestHelpers
import Testing

@Suite(.rulesRegistered)
struct DisableAllTests {
    /// Example violations. Could be replaced with other single violations.
    private static let violatingPhrases = #examples([
        "let r = 0",  // Violates identifier_name
        #"let myString:String = """#,  // Violates colon_whitespace
        "// TODO: Some todo",  // Violates todo
    ])

    // MARK: Violating Phrase
    /// Tests whether example violating phrases trigger when not applying disable rule
    @Test(arguments: violatingPhrases)
    func violatingPhrase(_ violatingPhrase: Example) {
        #expect(violations(violatingPhrase.with(code: violatingPhrase.code + "\n")).count == 1)
    }

    // MARK: Enable / Disable Base
    /// Tests whether oida:disable all protects properly
    @Test(arguments: violatingPhrases)
    func disableAll(_ violatingPhrase: Example) {
        let code = "// oida:disable all\n" + violatingPhrase.code + "\n// oida:enable all\n"
        let protectedPhrase = violatingPhrase.with(code: code)
        #expect(violations(protectedPhrase).isEmpty)
    }

    /// Tests whether oida:enable all unprotects properly
    @Test(arguments: violatingPhrases)
    func enableAll(_ violatingPhrase: Example) {
        let unprotectedPhrase = violatingPhrase.with(
            code: """
                // oida:disable all
                \(violatingPhrase.code)
                // oida:enable all
                \(violatingPhrase.code)\n
                """)
        #expect(violations(unprotectedPhrase).count == 1)
    }

    // MARK: Enable / Disable Previous
    /// Tests whether oida:disable:previous all protects properly
    @Test(arguments: violatingPhrases)
    func disableAllPrevious(_ violatingPhrase: Example) {
        let protectedPhrase =
            violatingPhrase
            .with(
                code: """
                    \(violatingPhrase.code)
                    // oida:disable:previous all\n
                    """)
        #expect(violations(protectedPhrase).isEmpty)
    }

    /// Tests whether oida:enable:previous all unprotects properly
    @Test(arguments: violatingPhrases)
    func enableAllPrevious(_ violatingPhrase: Example) {
        let unprotectedPhrase = violatingPhrase.with(
            code: """
                // oida:disable all
                \(violatingPhrase.code)
                \(violatingPhrase.code)
                // oida:enable:previous all
                // oida:enable all
                """)
        #expect(violations(unprotectedPhrase).count == 1)
    }

    // MARK: Enable / Disable Next
    /// Tests whether oida:disable:next all protects properly
    @Test(arguments: violatingPhrases)
    func disableAllNext(_ violatingPhrase: Example) {
        let protectedPhrase = violatingPhrase.with(code: "// oida:disable:next all\n" + violatingPhrase.code)
        #expect(violations(protectedPhrase).isEmpty)
    }

    /// Tests whether oida:enable:next all unprotects properly
    @Test(arguments: violatingPhrases)
    func enableAllNext(_ violatingPhrase: Example) {
        let unprotectedPhrase = violatingPhrase.with(
            code: """
                // oida:disable all
                \(violatingPhrase.code)
                // oida:enable:next all
                \(violatingPhrase.code)
                // oida:enable all
                """)
        #expect(violations(unprotectedPhrase).count == 1)
    }

    // MARK: Enable / Disable This
    /// Tests whether oida:disable:this all protects properly
    @Test(arguments: violatingPhrases)
    func disableAllThis(_ violatingPhrase: Example) {
        let rawViolatingPhrase = violatingPhrase.code.replacingOccurrences(of: "\n", with: "")
        let protectedPhrase = violatingPhrase.with(code: rawViolatingPhrase + "// oida:disable:this all\n")
        #expect(violations(protectedPhrase).isEmpty)
    }

    /// Tests whether oida:enable:next all unprotects properly
    @Test(arguments: violatingPhrases)
    func enableAllThis(_ violatingPhrase: Example) {
        let rawViolatingPhrase = violatingPhrase.code.replacingOccurrences(of: "\n", with: "")
        let unprotectedPhrase = violatingPhrase.with(
            code: """
                // oida:disable all
                \(violatingPhrase.code)
                \(rawViolatingPhrase)// oida:enable:this all
                // oida:enable all
                """)
        #expect(violations(unprotectedPhrase).count == 1)
    }
}
