import Foundation

extension Configuration {
    // MARK: Caching Configurations By Identifier (In-Memory)
    private static var cachedConfigurationsByIdentifier = [String: Configuration]()
    private static let cachedConfigurationsByIdentifierLock = NSLock()

    /// Since the cache is stored in a static var, this function is used to reset the cache during tests
    internal static func resetCache() {
        Self.cachedConfigurationsByIdentifierLock.lock()
        Self.cachedConfigurationsByIdentifier = [:]
        Self.cachedConfigurationsByIdentifierLock.unlock()
    }

    internal func setCached(forIdentifier identifier: String) {
        Self.cachedConfigurationsByIdentifierLock.lock()
        Self.cachedConfigurationsByIdentifier[identifier] = self
        Self.cachedConfigurationsByIdentifierLock.unlock()
    }

    internal static func getCached(forIdentifier identifier: String) -> Configuration? {
        cachedConfigurationsByIdentifierLock.lock()
        defer { cachedConfigurationsByIdentifierLock.unlock() }
        return cachedConfigurationsByIdentifier[identifier]
    }

    // MARK: Nested Config Is Self Cache
    private static var nestedConfigIsSelfByIdentifier = [String: Bool]()
    private static let nestedConfigIsSelfByIdentifierLock = NSLock()

    internal static func setIsNestedConfigurationSelf(forIdentifier identifier: String, value: Bool) {
        Self.nestedConfigIsSelfByIdentifierLock.lock()
        Self.nestedConfigIsSelfByIdentifier[identifier] = value
        Self.nestedConfigIsSelfByIdentifierLock.unlock()
    }

    internal static func getIsNestedConfigurationSelf(forIdentifier identifier: String) -> Bool {
        Self.nestedConfigIsSelfByIdentifierLock.lock()
        defer { Self.nestedConfigIsSelfByIdentifierLock.unlock() }
        return Self.nestedConfigIsSelfByIdentifier[identifier] ?? false
    }
}
