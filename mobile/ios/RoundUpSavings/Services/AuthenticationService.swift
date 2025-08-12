import Foundation
import LocalAuthentication

class AuthenticationService {
    static let shared = AuthenticationService()
    
    private var currentUser: User?
    private var accessToken: String?
    private var refreshToken: String?
    private let keychain = KeychainService()
    private let networkManager = NetworkManager.shared
    
    private init() {}
    
    func initialize() {
        // Check for existing session
        if let token = keychain.getAccessToken() {
            self.accessToken = token
            self.refreshToken = keychain.getRefreshToken()
            // Validate token and restore session
            validateToken(token)
        }
    }
    
    // MARK: - Authentication Methods
    
    func register(email: String, password: String, firstName: String, lastName: String) async throws -> User {
        let request = RegisterRequest(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            deviceId: getDeviceId(),
            marketingConsent: false
        )
        
        let response: APIResponse<AuthTokens> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.register,
            method: .POST,
            body: try request.toDictionary(),
            cachePolicy: .networkOnly
        )
        
        guard response.success, let tokens = response.data else {
            throw AuthError.registrationFailed
        }
        
        // Get user profile
        let userResponse: APIResponse<User> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.userProfile,
            cachePolicy: .networkOnly
        )
        
        guard userResponse.success, let user = userResponse.data else {
            throw AuthError.registrationFailed
        }
        
        // Store tokens and user
        updateTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        self.currentUser = user
        
        return user
    }
    
    func login(email: String, password: String) async throws -> User {
        let request = LoginRequest(
            email: email,
            password: password,
            deviceId: getDeviceId(),
            biometricEnabled: isBiometricsEnabled()
        )
        
        let response: APIResponse<AuthTokens> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.login,
            method: .POST,
            body: try request.toDictionary(),
            cachePolicy: .networkOnly
        )
        
        guard response.success, let tokens = response.data else {
            throw AuthError.invalidCredentials
        }
        
        // Get user profile
        let userResponse: APIResponse<User> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.userProfile,
            cachePolicy: .networkOnly
        )
        
        guard userResponse.success, let user = userResponse.data else {
            throw AuthError.invalidCredentials
        }
        
        // Store tokens and user
        updateTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        self.currentUser = user
        
        return user
    }
    
    func logout() {
        // Call logout endpoint
        Task {
            do {
                let _: APIResponse<Never> = try await networkManager.request(
                    endpoint: APIConstants.Endpoints.logout,
                    method: .POST,
                    cachePolicy: .networkOnly
                )
            } catch {
                // Ignore logout errors
                print("Logout API call failed: \(error)")
            }
        }
        
        // Clear local data
        currentUser = nil
        accessToken = nil
        refreshToken = nil
        keychain.deleteAccessToken()
        keychain.deleteRefreshToken()
        
        // Clear network cache
        networkManager.clearCache()
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthError.biometricsNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                 localizedReason: "Authenticate to access your financial data") { success, error in
                if let error = error {
                    continuation.resume(throwing: AuthError.biometricAuthenticationFailed(error))
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    func forgotPassword(email: String) async throws {
        let request = ForgotPasswordRequest(email: email)
        
        let response: APIResponse<Never> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.forgotPassword,
            method: .POST,
            body: try request.toDictionary(),
            cachePolicy: .networkOnly
        )
        
        guard response.success else {
            throw AuthError.passwordResetFailed
        }
    }
    
    func resetPassword(token: String, newPassword: String) async throws {
        let request = ResetPasswordRequest(token: token, newPassword: newPassword)
        
        let response: APIResponse<Never> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.resetPassword,
            method: .POST,
            body: try request.toDictionary(),
            cachePolicy: .networkOnly
        )
        
        guard response.success else {
            throw AuthError.passwordResetFailed
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        let request = ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        
        let response: APIResponse<Never> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.changePassword,
            method: .POST,
            body: try request.toDictionary(),
            cachePolicy: .networkOnly
        )
        
        guard response.success else {
            throw AuthError.passwordChangeFailed
        }
    }
    
    // MARK: - User Management
    
    func getCurrentUser() -> User? {
        return currentUser
    }
    
    func updateProfile(firstName: String, lastName: String, phone: String?) async throws -> User {
        let body: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "phone": phone ?? ""
        ]
        
        let response: APIResponse<User> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.updateProfile,
            method: .PUT,
            body: body,
            cachePolicy: .networkOnly
        )
        
        guard response.success, let user = response.data else {
            throw AuthError.updateFailed
        }
        
        self.currentUser = user
        return user
    }
    
    func deleteAccount() async throws {
        let response: APIResponse<Never> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.deleteAccount,
            method: .DELETE,
            cachePolicy: .networkOnly
        )
        
        guard response.success else {
            throw AuthError.deleteAccountFailed
        }
        
        // Clear local data
        logout()
    }
    
    // MARK: - Token Management
    
    func updateTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        keychain.saveAccessToken(accessToken)
        keychain.saveRefreshToken(refreshToken)
    }
    
    func getAccessToken() -> String? {
        return accessToken
    }
    
    func getRefreshToken() -> String? {
        return refreshToken
    }
    
    func isAuthenticated() -> Bool {
        return accessToken != nil && currentUser != nil
    }
    
    // MARK: - Private Methods
    
    private func validateToken(_ token: String) {
        Task {
            do {
                let response: APIResponse<User> = try await networkManager.request(
                    endpoint: APIConstants.Endpoints.validate,
                    cachePolicy: .networkOnly
                )
                
                if response.success, let user = response.data {
                    self.currentUser = user
                } else {
                    // Token is invalid, clear it
                    self.logout()
                }
            } catch {
                // Token validation failed, clear it
                self.logout()
            }
        }
    }
    
    private func getDeviceId() -> String {
        if let deviceId = UserDefaults.standard.string(forKey: "device_id") {
            return deviceId
        }
        
        let deviceId = UUID().uuidString
        UserDefaults.standard.set(deviceId, forKey: "device_id")
        return deviceId
    }
    
    private func isBiometricsEnabled() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - Helper Methods
    
    func getAuthHeaders() -> [String: String] {
        guard let token = accessToken else {
            return [:]
        }
        return ["Authorization": "Bearer \(token)"]
    }
}

// MARK: - Supporting Types

enum AuthError: Error, LocalizedError {
    case registrationFailed
    case invalidCredentials
    case notAuthenticated
    case biometricsNotAvailable
    case biometricAuthenticationFailed(Error)
    case updateFailed
    case passwordResetFailed
    case passwordChangeFailed
    case deleteAccountFailed
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Registration failed. Please try again."
        case .invalidCredentials:
            return "Invalid email or password."
        case .notAuthenticated:
            return "You must be logged in to perform this action."
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometricAuthenticationFailed(let error):
            return "Biometric authentication failed: \(error.localizedDescription)"
        case .updateFailed:
            return "Failed to update profile. Please try again."
        case .passwordResetFailed:
            return "Failed to send password reset email. Please try again."
        case .passwordChangeFailed:
            return "Failed to change password. Please try again."
        case .deleteAccountFailed:
            return "Failed to delete account. Please try again."
        case .tokenRefreshFailed:
            return "Session expired. Please log in again."
        }
    }
}

// MARK: - Extensions

extension LoginRequest {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

extension RegisterRequest {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

extension ForgotPasswordRequest {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

extension ResetPasswordRequest {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

extension ChangePasswordRequest {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
