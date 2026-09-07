import SwiftLintCore
import Testing

@Suite
struct RegionTests {
    @Test
    func noRegionsInEmptyFile() {
        let file = SwiftLintFile(contents: "")
        #expect(file.regions().isEmpty)
    }

    @Test
    func noRegionsInFileWithNoCommands() {
        let file = SwiftLintFile(contents: String(repeating: "\n", count: 100))
        #expect(file.regions().isEmpty)
    }

    @Test
    func regionsFromSingleCommand() {
        // disable
        do {
            let command = "// oida:disable rule_id"
            let file = SwiftLintFile(contents: command + "\n")
            let start = Location(file: nil, line: 1, character: command.count + 1)
            let end = Location(file: nil, line: .max, character: .max)
            #expect(file.regions() == [Region(start: start, end: end, disabledRuleIdentifiers: ["rule_id"])])
        }
        // enable
        do {
            let command = "// oida:enable rule_id"
            let file = SwiftLintFile(contents: command + "\n")
            let start = Location(file: nil, line: 1, character: command.count + 1)
            let end = Location(file: nil, line: .max, character: .max)
            #expect(file.regions() == [Region(start: start, end: end, disabledRuleIdentifiers: [])])
        }
    }

    @Test
    func regionsFromMatchingPairCommands() {
        // disable/enable
        do {
            let disable = "// oida:disable rule_id"
            let enable = "// oida:enable rule_id"
            let file = SwiftLintFile(contents: disable + "\n" + enable + "\n")
            #expect(file.regions() == [
                Region(
                    start: Location(file: nil, line: 1, character: disable.count + 1),
                    end: Location(file: nil, line: 2, character: enable.count),
                    disabledRuleIdentifiers: ["rule_id"]),
                Region(
                    start: Location(file: nil, line: 2, character: enable.count + 1),
                    end: Location(file: nil, line: .max, character: .max),
                    disabledRuleIdentifiers: []),
            ])
        }
        // enable/disable
        do {
            let enable = "// oida:enable rule_id"
            let disable = "// oida:disable rule_id"
            let file = SwiftLintFile(contents: enable + "\n" + disable + "\n")
            #expect(file.regions() == [
                Region(
                    start: Location(file: nil, line: 1, character: enable.count + 1),
                    end: Location(file: nil, line: 2, character: disable.count),
                    disabledRuleIdentifiers: []),
                Region(
                    start: Location(file: nil, line: 2, character: disable.count + 1),
                    end: Location(file: nil, line: .max, character: .max),
                    disabledRuleIdentifiers: ["rule_id"]),
            ])
        }
    }

    @Test
    func regionsFromThreeCommandForSingleLine() {
        let file = SwiftLintFile(
            contents: "// oida:disable:next 1\n" + "// oida:disable:this 2\n"
                + "// oida:disable:previous 3\n")
        #expect(file.regions() == [
            Region(
                start: Location(file: nil, line: 2, character: nil),
                end: Location(file: nil, line: 2, character: .max - 1),
                disabledRuleIdentifiers: ["1", "2", "3"]),
            Region(
                start: Location(file: nil, line: 2, character: .max),
                end: Location(file: nil, line: .max, character: .max),
                disabledRuleIdentifiers: []),
        ])
    }

    @Test
    func severalRegionsFromSeveralCommands() {
        let commands = [
            "// oida:disable 1",
            "// oida:disable 2",
            "// oida:disable 3",
            "// oida:enable 1",
            "// oida:enable 2",
            "// oida:enable 3",
        ]
        let file = SwiftLintFile(contents: commands.joined(separator: "\n"))

        // A region opens one column past the command that starts it and closes at the end of the command
        // that ends it, so both are read off the commands rather than written out.
        func opens(atLine line: Int) -> Location {
            Location(file: nil, line: line, character: commands[line - 1].count + 1)
        }
        func closes(atLine line: Int) -> Location {
            Location(file: nil, line: line, character: commands[line - 1].count)
        }

        #expect(file.regions() == [
            Region(
                start: opens(atLine: 1),
                end: closes(atLine: 2),
                disabledRuleIdentifiers: ["1"]),
            Region(
                start: opens(atLine: 2),
                end: closes(atLine: 3),
                disabledRuleIdentifiers: ["1", "2"]),
            Region(
                start: opens(atLine: 3),
                end: closes(atLine: 4),
                disabledRuleIdentifiers: ["1", "2", "3"]),
            Region(
                start: opens(atLine: 4),
                end: closes(atLine: 5),
                disabledRuleIdentifiers: ["2", "3"]),
            Region(
                start: opens(atLine: 5),
                end: closes(atLine: 6),
                disabledRuleIdentifiers: ["3"]),
            Region(
                start: opens(atLine: 6),
                end: Location(file: nil, line: .max, character: .max),
                disabledRuleIdentifiers: []),
        ])
    }
}
