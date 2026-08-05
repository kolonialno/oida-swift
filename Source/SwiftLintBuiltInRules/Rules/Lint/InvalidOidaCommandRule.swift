import Foundation
import SourceKittenFramework
import SwiftLintCore

struct InvalidOidaCommandRule: Rule, SourceKitFreeRule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "invalid_oida_command",
        name: "Invalid oida Command",
        description: "oida command is invalid",
        kind: .lint,
        nonTriggeringExamples: #examples([
            "// oida:disable unused_import",
            "// oida:enable unused_import",
            "// oida:disable:next unused_import",
            "// oida:disable:previous unused_import",
            "// oida:disable:this unused_import",
            "//oida:disable:this unused_import",
            "_ = \"🤵🏼‍♀️\" // oida:disable:this unused_import".asExample(excludeFromDocumentation: true),
            "_ = \"🤵🏼‍♀️ 🤵🏼‍♀️\" // oida:disable:this unused_import".asExample(excludeFromDocumentation: true),
        ]),
        triggeringExamples: #examples([
            "// ↓oida:",
            "// ↓oida: ",
            "// ↓oida::",
            "// ↓oida:: ",
            "// ↓oida:disable",
            "// ↓oida:dissable unused_import",
            "// ↓oida:enaaaable unused_import",
            "// ↓oida:disable:nxt unused_import",
            "// ↓oida:enable:prevus unused_import",
            "// ↓oida:enable:ths unused_import",
            "// ↓oida:enable",
            "// ↓oida:enable:",
            "// ↓oida:enable: ",
            "// ↓oida:disable: unused_import",
            "// s↓oida:disable unused_import",
            "// 🤵🏼‍♀️oida:disable unused_import".asExample(excludeFromDocumentation: true),
        ]).skipWrappingInCommentTests()
    )

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        badPrefixViolations(in: file) + invalidCommandViolations(in: file)
    }

    private func badPrefixViolations(in file: SwiftLintFile) -> [StyleViolation] {
        (file.commands + file.invalidCommands).compactMap { command in
            command.isPrecededByInvalidCharacter(in: file)
                ? styleViolation(
                    for: command,
                    in: file,
                    reason: "swiftlint command should be preceded by whitespace or a comment character"
                )
                : nil
        }
    }

    private func invalidCommandViolations(in file: SwiftLintFile) -> [StyleViolation] {
        file.invalidCommands.map { command in
            styleViolation(for: command, in: file, reason: command.invalidReason() ?? Self.description.description)
        }
    }

    private func styleViolation(for command: Command, in file: SwiftLintFile, reason: String) -> StyleViolation {
        StyleViolation(
            ruleDescription: Self.description,
            severity: configuration.severity,
            location: Location(file: file.path, line: command.line, character: command.range?.lowerBound),
            reason: reason
        )
    }
}

private extension Command {
    func isPrecededByInvalidCharacter(in file: SwiftLintFile) -> Bool {
        guard line > 0, let character = range?.lowerBound, character > 1, line <= file.lines.count else {
            return false
        }
        let line = file.lines[line - 1].content
        guard line.count > character,
              let char = line[line.index(line.startIndex, offsetBy: character - 2)].unicodeScalars.first else {
            return false
        }
        return !CharacterSet.whitespaces.union(CharacterSet(charactersIn: "/")).contains(char)
    }

    func invalidReason() -> String? {
        if action == .invalid {
            return "swiftlint command does not have a valid action"
        }
        if modifier == .invalid {
            return "swiftlint command does not have a valid modifier"
        }
        if ruleIdentifiers.isEmpty {
            return "swiftlint command does not specify any rules"
        }
        return nil
    }
}
