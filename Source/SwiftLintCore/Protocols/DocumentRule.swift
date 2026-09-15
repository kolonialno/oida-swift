/// A rule that lints a Markdown document rather than Swift source, validating `file.contents` directly the
/// way `CustomRules` does — never touching `file.syntaxTree`, which a Markdown file can't produce.
///
/// `Linter` excludes every `DocumentRule` from the Swift-file pass, and only a document rule's own lint pass
/// runs it, so a document rule can never see a `.swift` file and a `SwiftSyntaxRule` can never see a `.md`
/// one — the two file kinds stay on structurally separate tracks.
public protocol DocumentRule: SourceKitFreeRule {}
