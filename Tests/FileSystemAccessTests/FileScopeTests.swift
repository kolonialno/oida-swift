import Foundation
import SwiftLintCore
import TestHelpers
import Testing

@testable import SwiftLintBuiltInRules

/// A scope is written to name paths inside the repository, so it is matched against the path from the
/// working directory down — never the absolute one, which carries the checkout's own directory name and
/// makes every anchored pattern depend on what the clone was called.
@Suite(.rulesRegistered)
struct FileScopeTests {
    @Test(.temporaryDirectory)
    func aScopeAnchoredAtTheRootMatchesARootDocument() throws {
        let path = URL.cwd.appending(path: "README.md")
        try "text".write(to: path, atomically: true, encoding: .utf8)
        let file = try #require(SwiftLintFile(path: path))
        #expect(FileScope(included: "^README\\.md$", excluded: nil).contains(file))
    }

    @Test(.temporaryDirectory)
    func aScopeAnchoredAtTheRootSkipsTheSameNameDeeper() throws {
        let directory = URL.cwd.appending(path: "Nested")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appending(path: "README.md")
        try "text".write(to: path, atomically: true, encoding: .utf8)
        let file = try #require(SwiftLintFile(path: path))
        #expect(!FileScope(included: "^README\\.md$", excluded: nil).contains(file))
    }

    @Test(.temporaryDirectory)
    func anUnanchoredScopeStillMatchesDeeper() throws {
        let directory = URL.cwd.appending(path: "SharedApp")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appending(path: "Screen.swift")
        try "struct S {}".write(to: path, atomically: true, encoding: .utf8)
        let file = try #require(SwiftLintFile(path: path))
        #expect(FileScope(included: "SharedApp/.*\\.swift", excluded: nil).contains(file))
    }
}
