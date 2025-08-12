import Foundation
import Security

class KeychainService {
    
    private let service = "com.ascend.app"
    
    // MARK: - Authentication Tokens
    
    func saveAccessToken(_ token: String) {
        save(key: "access_token", data: token)
    }
    
    func getAccessToken() -> String? {
        return get(key: "access_token")
    }
    
    func deleteAccessToken() {
        delete(key: "access_token")
    }
    
    func saveRefreshToken(_ token: String) {
        save(key: "refresh_token", data: token)
    }
    
    func getRefreshToken() -> String? {
        return get(key: "refresh_token")
    }
    
    func deleteRefreshToken() {
        delete(key: "refresh_token")
    }
    
    // MARK: - Legacy Support (for backward compatibility)
    
    func saveAuthToken(_ token: String) {
        saveAccessToken(token)
    }
    
    func getAuthToken() -> String? {
        return getAccessToken()
    }
    
    func deleteAuthToken() {
        deleteAccessToken()
    }
    
    // MARK: - Plaid Integration
    
    func savePlaidToken(_ token: String) {
        save(key: "plaid_token", data: token)
    }
    
    func getPlaidToken() -> String? {
        return get(key: "plaid_token")
    }
    
    func deletePlaidToken() {
        delete(key: "plaid_token")
    }
    
    // MARK: - User Data
    
    func saveUserData(_ data: Data) {
        saveData(key: "user_data", data: data)
    }
    
    func getUserData() -> Data? {
        return getData(key: "user_data")
    }
    
    func deleteUserData() {
        delete(key: "user_data")
    }
    
    // MARK: - Biometric Keys
    
    func saveBiometricKey(_ key: String) {
        save(key: "biometric_key", data: key)
    }
    
    func getBiometricKey() -> String? {
        return get(key: "biometric_key")
    }
    
    func deleteBiometricKey() {
        delete(key: "biometric_key")
    }
    
    // MARK: - Device ID
    
    func saveDeviceId(_ deviceId: String) {
        save(key: "device_id", data: deviceId)
    }
    
    func getDeviceId() -> String? {
        return get(key: "device_id")
    }
    
    func deleteDeviceId() {
        delete(key: "device_id")
    }
    
    // MARK: - Private Methods
    
    private func save(key: String, data: String) {
        guard let data = data.data(using: .utf8) else { return }
        saveData(key: key, data: data)
    }
    
    private func saveData(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("Keychain save failed for key \(key): \(status)")
        }
    }
    
    private func get(key: String) -> String? {
        guard let data = getData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func getData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        } else if status == errSecItemNotFound {
            return nil
        } else {
            print("Keychain get failed for key \(key): \(status)")
            return nil
        }
    }
    
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Keychain delete failed for key \(key): \(status)")
        }
    }
    
    // MARK: - Utilities
    
    func clearAllData() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Keychain clear all failed: \(status)")
        }
    }
    
    func getAllKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            return items.compactMap { $0[kSecAttrAccount as String] as? String }
        }
        
        return []
    }
    
    func keyExists(_ key: String) -> Bool {
        return get(key: key) != nil
    }
}

// MARK: - Keychain Error Handling

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case getFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .getFailed(let status):
            return "Failed to get from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .itemNotFound:
            return "Item not found in keychain"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
