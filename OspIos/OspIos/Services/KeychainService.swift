import Foundation
import KeychainSwift

class KeychainService {
    private let keychain = KeychainSwift()
    
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    private let providerKey = "auth_provider"
    
    init() {
        // Configure keychain with default accessibility
        keychain.accessibility = .whenUnlocked
    }
    
    /// Store authentication tokens and provider
    /// - Parameters:
    ///   - accessToken: The access token from authentication
    ///   - refreshToken: The refresh token from authentication
    ///   - provider: The authentication provider (e.g., "apple")
    /// - Returns: Bool indicating success of storage
    func storeTokens(accessToken: String, refreshToken: String, provider: String) -> Bool {
        let accessStored = keychain.set(accessToken, forKey: accessTokenKey)
        let refreshStored = keychain.set(refreshToken, forKey: refreshTokenKey)
        let providerStored = keychain.set(provider, forKey: providerKey)
        
        return accessStored && refreshStored && providerStored
    }
    
    /// Retrieve access token
    /// - Returns: Optional access token string
    func getAccessToken() -> String? {
        return keychain.get(accessTokenKey)
    }
    
    /// Retrieve refresh token
    /// - Returns: Optional refresh token string
    func getRefreshToken() -> String? {
        return keychain.get(refreshTokenKey)
    }
    
    /// Retrieve authentication provider
    /// - Returns: Optional provider string
    func getAuthProvider() -> String? {
        return keychain.get(providerKey)
    }
    
    /// Check if user is currently authenticated
    /// - Returns: Bool indicating authentication state
    func isAuthenticated() -> Bool {
        return getAccessToken() != nil
    }
    
    /// Clear all authentication tokens
    /// - Returns: Bool indicating success of deletion
    func clearTokens() -> Bool {
        let accessCleared = keychain.delete(accessTokenKey)
        let refreshCleared = keychain.delete(refreshTokenKey)
        let providerCleared = keychain.delete(providerKey)
        
        return accessCleared && refreshCleared && providerCleared
    }
}
