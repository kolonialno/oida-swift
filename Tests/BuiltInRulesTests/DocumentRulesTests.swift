import Foundation
import SwiftLintCore
import TestHelpers
import Testing

@testable import SwiftLintBuiltInRules

/// Document rules validate Markdown prose, not Swift syntax, so their examples aren't Swift code and
/// `verifyRule`'s Swift-comment/string-wrapping checks don't apply to them (see `Rules+Register.swift`,
/// which excludes `Rules/Document` from the generated example-based tests). These are hand-written instead.
@Suite(.rulesRegistered)
struct DocumentRulesTests {
    @Test
    func saysWhatIsFlagsANegationOutsideCode() {
        let rule = DocumentSaysWhatIsRule()
        let file = SwiftLintFile(contents: "This never fails.")
        let expected = "Says \"never\" — state the positive core instead of what isn't true"
        #expect(rule.validate(file: file).map(\.reason) == [expected])
    }

    @Test
    func saysWhatIsIgnoresCodeQuotesLinksAndAddresses() {
        let rule = DocumentSaysWhatIsRule()
        let file = SwiftLintFile(contents: """
            `never` is fine inline.

            ```
            This never fails inside a fence.
            ```

            See https://example.com/never for details.
            """)
        #expect(rule.validate(file: file).isEmpty)
    }

    @Test
    func avoidsRetiredWordsFlagsOne() {
        let rule = DocumentAvoidsRetiredWordsRule()
        let file = SwiftLintFile(contents: "This will leverage the cache.")
        #expect(rule.validate(file: file).map(\.reason) == ["Uses \"leverage\" — say what the thing does instead"])
    }

    @Test
    func avoidsRetiredWordsAllowsPlainWords() {
        let rule = DocumentAvoidsRetiredWordsRule()
        let file = SwiftLintFile(contents: "This retries automatically on failure.")
        #expect(rule.validate(file: file).isEmpty)
    }

    @Test(.temporaryDirectory)
    func linksResolveFlagsAMissingTarget() throws {
        let path = URL.cwd.appending(path: "README.md")
        try "[See the guidelines](does-not-exist.md)".write(to: path, atomically: true, encoding: .utf8)

        let rule = DocumentLinksResolveRule()
        let violations = rule.validate(file: SwiftLintFile(path: path)!)
        #expect(violations.map(\.reason) == ["Links to does-not-exist.md, which is missing"])
    }

    @Test(.temporaryDirectory)
    func linksResolveAllowsATargetThatExists() throws {
        let path = URL.cwd.appending(path: "README.md")
        try FileManager.default.createDirectory(at: URL.cwd.appending(path: "docs"), withIntermediateDirectories: true)
        try "".write(to: URL.cwd.appending(path: "docs/guide.md"), atomically: true, encoding: .utf8)
        try "[See the guidelines](docs/guide.md)".write(to: path, atomically: true, encoding: .utf8)

        let rule = DocumentLinksResolveRule()
        #expect(rule.validate(file: SwiftLintFile(path: path)!).isEmpty)
    }

    @Test(.temporaryDirectory)
    func linksResolveFollowsALinkOutOfASubdirectory() throws {
        let readme = URL.cwd.appending(path: "README.md")
        try "".write(to: readme, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: URL.cwd.appending(path: "docs"), withIntermediateDirectories: true)
        let collected = URL.cwd.appending(path: "docs/collected.md")
        try "[The root document](../README.md)".write(to: collected, atomically: true, encoding: .utf8)

        let rule = DocumentLinksResolveRule()
        #expect(rule.validate(file: SwiftLintFile(path: collected)!).isEmpty)
    }

    @Test(.temporaryDirectory)
    func linksResolveRejectsATargetOnlyTheRootWouldFind() throws {
        try FileManager.default.createDirectory(at: URL.cwd.appending(path: "docs"), withIntermediateDirectories: true)
        try "".write(to: URL.cwd.appending(path: "docs/guide.md"), atomically: true, encoding: .utf8)
        let collected = URL.cwd.appending(path: "docs/collected.md")
        try "[The guide](docs/guide.md)".write(to: collected, atomically: true, encoding: .utf8)

        let rule = DocumentLinksResolveRule()
        #expect(
            rule.validate(file: SwiftLintFile(path: collected)!).map(\.reason)
                == ["Links to docs/guide.md, which is missing"]
        )
    }

    @Test(.temporaryDirectory)
    func linksResolveSkipsExternalAndFragmentLinks() throws {
        let path = URL.cwd.appending(path: "README.md")
        try """
        [External](https://example.com/anything)
        [Skip ahead](#a-heading)
        [Mail](mailto:someone@example.com)
        """.write(to: path, atomically: true, encoding: .utf8)

        let rule = DocumentLinksResolveRule()
        #expect(rule.validate(file: SwiftLintFile(path: path)!).isEmpty)
    }
}
