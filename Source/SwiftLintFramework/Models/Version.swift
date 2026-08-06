/// A type describing the SwiftLint version.
public struct Version: VersionComparable, Sendable {
    /// The string value for this version.
    public let value: String

    /// An alias for `value` required for protocol conformance.
    public var rawValue: String {
        value
    }

    /// The current version.
    ///
    /// Ours, counted from one: this is oida, whose rules and shape decisions are its own. The number a
    /// consumer pins is this one, so it can never be confused with the SwiftLint release the code grew from.
    public static let current = Self(value: "0.5.0")

    /// Public initializer.
    ///
    /// - parameter value: The string value for this version.
    public init(value: String) {
        self.value = value
    }
}
