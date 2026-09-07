@testable import SwiftLintFramework
import TestHelpers
import Testing

@Suite(.rulesRegistered, .temporaryDirectory)
struct ResultReuseTests {
    /// A rule's verdict can depend on files other than the one being linted — `document_links_resolve` reads
    /// the link target, `no_single_use_void_functions` resolves receivers across the whole run — while a
    /// persisted result is keyed on the linted file's own modification date. Reusing one then reports the
    /// repository as it was when the entry was written: a pruned link target stays resolved, and a function
    /// that has since gained a second caller stays condemned.
    @Test
    func aRunNeverReusesAnotherRunsResults() {
        let builder = LintOrAnalyzeResultBuilder(LintOrAnalyzeOptions(ignoreCache: false))

        #expect(builder.cache == nil)
    }
}

private extension LintOrAnalyzeOptions {
    init(ignoreCache: Bool) {
        self.init(mode: .lint,
                  paths: [],
                  useSTDIN: true,
                  configurationFiles: [],
                  strict: false,
                  lenient: false,
                  forceExclude: false,
                  useExcludingByPrefix: false,
                  useScriptInputFiles: false,
                  useScriptInputFileLists: false,
                  benchmark: false,
                  reporter: nil,
                  baseline: nil,
                  writeBaseline: nil,
                  workingDirectory: nil,
                  quiet: true,
                  output: nil,
                  progress: false,
                  cachePath: nil,
                  ignoreCache: ignoreCache,
                  enableAllRules: false,
                  onlyRule: [],
                  autocorrect: false,
                  format: false,
                  disableSourceKit: false,
                  compilerLogPath: nil,
                  compileCommands: nil,
                  checkForUpdates: false
        )
    }
}
