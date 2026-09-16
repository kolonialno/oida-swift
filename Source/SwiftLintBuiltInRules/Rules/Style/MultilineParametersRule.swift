import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(explicitRewriter: true, optIn: true)
struct MultilineParametersRule: Rule {
    var configuration = MultilineParametersConfiguration()

    static let description = RuleDescription(
        identifier: "multiline_parameters",
        name: "Multiline Parameters",
        description: "Functions and methods parameters should be either on the same line, or one per line",
        kind: .style,
        nonTriggeringExamples: MultilineParametersRuleExamples.nonTriggeringExamples,
        triggeringExamples: MultilineParametersRuleExamples.triggeringExamples,
        corrections: MultilineParametersRuleExamples.corrections
    )
}

private extension MultilineParametersRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionDeclSyntax) {
            if containsViolation(for: node.signature, of: node) || isSplitWithinAllowance(node.signature, of: node) {
                violations.append(node.name.positionAfterSkippingLeadingTrivia)
            }
        }

        override func visitPost(_ node: InitializerDeclSyntax) {
            if containsViolation(for: node.signature, of: node) || isSplitWithinAllowance(node.signature, of: node) {
                violations.append(node.initKeyword.positionAfterSkippingLeadingTrivia)
            }
        }

        /// A parameter list within the allowance that is split anyway, which the rewriter brings back to
        /// one line.
        private func isSplitWithinAllowance(
            _ signature: FunctionSignatureSyntax,
            of declaration: some SyntaxProtocol
        ) -> Bool {
            configuration.requiresSingleLine
                && signature.parameterClause.canRejoinOneLine(within: configuration)
                && declaration.headerKeptByFormatter(
                    parametersJoined: true, positionsFrom: declaration, in: file, locationConverter: locationConverter)
        }

        private func containsViolation(
            for signature: FunctionSignatureSyntax,
            of declaration: some SyntaxProtocol
        ) -> Bool {
            let parameterPositions = signature.parameterClause.parameters.map(\.positionAfterSkippingLeadingTrivia)
            guard parameterPositions.isNotEmpty else {
                return false
            }

            var numberOfParameters = 0
            var linesWithParameters: Set<Int> = []
            var hasMultipleParametersOnSameLine = false

            for position in parameterPositions {
                let line = locationConverter.location(for: position).line

                if !linesWithParameters.insert(line).inserted {
                    hasMultipleParametersOnSameLine = true
                }

                numberOfParameters += 1
            }

            if linesWithParameters.count == 1 {
                guard configuration.allowsSingleLine else {
                    return numberOfParameters > 1
                }

                if let maxNumberOfSingleLineParameters = configuration.maxNumberOfSingleLineParameters,
                   numberOfParameters > maxNumberOfSingleLineParameters {
                    return true
                }

                // Within the allowance yet too wide: the formatter wraps the return clause and drops the brace
                // below it, so these go one per line, which it keeps.
                return numberOfParameters > 1
                    && configuration.requiresSingleLine
                    && !declaration.headerKeptByFormatter(
                        parametersJoined: false, positionsFrom: declaration, in: file, locationConverter: locationConverter)
            }

            return hasMultipleParametersOnSameLine
        }
    }
}

private extension MultilineParametersRule {
    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
            if let split = splitting(node.signature, of: node) {
                return super.visit(node.with(\.signature, split))
            }
            let visited = super.visit(node)
            guard let declaration = visited.as(FunctionDeclSyntax.self),
                  let joined = joining(declaration.signature, of: declaration, positionsFrom: node)
            else {
                return visited
            }
            return DeclSyntax(declaration.with(\.signature, joined))
        }

        override func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
            if let split = splitting(node.signature, of: node) {
                return super.visit(node.with(\.signature, split))
            }
            let visited = super.visit(node)
            guard let declaration = visited.as(InitializerDeclSyntax.self),
                  let joined = joining(declaration.signature, of: declaration, positionsFrom: node)
            else {
                return visited
            }
            return DeclSyntax(declaration.with(\.signature, joined))
        }

        /// The signature with its parameters one per line, or `nil` when they do not need it.
        ///
        /// Decided before descending, so that a nested list can read the line this puts it on.
        private func splitting(
            _ signature: FunctionSignatureSyntax,
            of declaration: some SyntaxProtocol
        ) -> FunctionSignatureSyntax? {
            let clause = signature.parameterClause
            let parameters = clause.parameters
            guard !parameters.isEmpty, !parameters.containsComment else {
                return nil
            }
            let onOneLineTooWide =
                configuration.requiresSingleLine
                    && !declaration.headerKeptByFormatter(
                        parametersJoined: false,
                        positionsFrom: declaration,
                        in: file,
                        locationConverter: locationConverter)
            let needsSplitting =
                (parameters.count > 1
                    && parameters.isOnOneLine
                    && (parameters.exceedsSingleLineAllowance(configuration) || onOneLineTooWide))
                // Neither one line nor one per line, which is the shape this rule is named for. A list that
                // could simply come back to one line does that instead, since splitting it further would be
                // the opposite of what the allowance asks for — and the visitor reports the join, not a split.
                || (parameters.isSplitUnevenly && !clause.canRejoinOneLine(within: configuration))
                // Where the join is what would take it and the join declines — a header the formatter would
                // break — this is the only way out left.
                || (parameters.isSplitUnevenly
                    && configuration.requiresSingleLine
                    && !joins(signature, of: declaration, positionsFrom: declaration))
            guard needsSplitting else {
                return nil
            }
            numberOfCorrections += 1
            return signature.with(\.parameterClause, split(clause))
        }

        /// The signature with its parameters back on one line, or `nil` when they cannot come back.
        ///
        /// Decided after descending: a default value coming back to one line is what can make the whole
        /// list joinable, and deciding first would leave that for a second run over the file.
        /// Whether the parameters are coming back to one line: few enough for the allowance, and on a
        /// header the formatter keeps there. Asked by the split too, so the two cannot both decline.
        private func joins(
            _ signature: FunctionSignatureSyntax,
            of declaration: some SyntaxProtocol,
            positionsFrom original: some SyntaxProtocol
        ) -> Bool {
            configuration.requiresSingleLine
                && signature.parameterClause.canRejoinOneLine(within: configuration)
                && declaration.headerKeptByFormatter(
                    parametersJoined: true, positionsFrom: original, in: file, locationConverter: locationConverter)
        }

        private func joining(
            _ signature: FunctionSignatureSyntax,
            of declaration: some SyntaxProtocol,
            positionsFrom original: some SyntaxProtocol
        ) -> FunctionSignatureSyntax? {
            guard joins(signature, of: declaration, positionsFrom: original) else {
                return nil
            }
            let clause = signature.parameterClause
            numberOfCorrections += 1
            return signature.with(\.parameterClause, clause.joinedOnOneLine)
        }

        private func split(_ clause: FunctionParameterClauseSyntax) -> FunctionParameterClauseSyntax {
            let indentation = clause.indentationOfOwnLine
            return clause
                .with(\.parameters, clause.parameters.splitOnePerLine(from: indentation))
                .with(\.rightParen, clause.rightParen.with(\.leadingTrivia, .newline + indentation))
        }
    }
}

extension MultilineParametersConfiguration: SingleLineAllowance {}

private extension FunctionParameterClauseSyntax {
    var joinedOnOneLine: FunctionParameterClauseSyntax {
        with(\.leftParen, leftParen.with(\.trailingTrivia, []))
            .with(\.parameters, parameters.joinedOnOneLine(startingWith: []))
            .with(\.rightParen, rightParen.with(\.leadingTrivia, []))
    }

    /// Whether the parameters can come back to one line. The closing paren is checked here because a comment
    /// before it would be lost.
    func canRejoinOneLine(within allowance: some SingleLineAllowance) -> Bool {
        !parameters.isEmpty
            && !parameters.isOnOneLine
            && !parameters.exceedsSingleLineAllowance(allowance)
            && !rightParen.leadingTrivia.containsComment
            && parameters.canRejoinOneLine
    }
}

private extension SyntaxProtocol {
    func headerKeptByFormatter(
        parametersJoined: Bool,
        positionsFrom original: some SyntaxProtocol,
        in file: SwiftLintFile,
        locationConverter: SourceLocationConverter
    ) -> Bool {
        guard let (header, hasBody) = oneLineHeader(parametersJoined: parametersJoined) else {
            return true
        }
        return formatterKeeps(
            header + (hasBody ? " {" : ""),
            in: header + (hasBody ? " {}" : ""),
            indentedLike: original,
            in: file,
            locationConverter: locationConverter
        )
    }

    /// Attributes drop out because the formatter keeps them on lines of their own, where they would
    /// otherwise count against the header.
    private func oneLineHeader(parametersJoined: Bool) -> (header: String, hasBody: Bool)? {
        let stripped: any SyntaxProtocol
        let hasBody: Bool
        if let function = `as`(FunctionDeclSyntax.self) {
            var header = function.with(\.body, nil).with(\.attributes, AttributeListSyntax([]))
            if parametersJoined {
                header = header.with(\.signature.parameterClause, header.signature.parameterClause.joinedOnOneLine)
            }
            stripped = header
            hasBody = function.body != nil
        } else if let initializer = `as`(InitializerDeclSyntax.self) {
            var header = initializer.with(\.body, nil).with(\.attributes, AttributeListSyntax([]))
            if parametersJoined {
                header = header.with(\.signature.parameterClause, header.signature.parameterClause.joinedOnOneLine)
            }
            stripped = header
            hasBody = initializer.body != nil
        } else {
            return nil
        }
        return (stripped.trimmedDescription.split(whereSeparator: \.isWhitespace).joined(separator: " "), hasBody)
    }
}
