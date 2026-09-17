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

    /// `/tmp` is a link to `/private/tmp`, and a checkout reached through any such link gives a working
    /// directory spelled differently from the files underneath it.
    @Test(.temporaryDirectory)
    func aScopeMatchesThroughASymlinkedWorkingDirectory() throws {
        let real = URL.cwd.appending(path: "real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = URL.cwd.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let path = real.appending(path: "README.md")
        try "text".write(to: path, atomically: true, encoding: .utf8)
        let file = try #require(SwiftLintFile(path: path))
        try CurrentWorkingDirectory.$url.withValue(link) {
            #expect(FileScope(included: "^README\\.md$", excluded: nil).contains(file))
        }
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
