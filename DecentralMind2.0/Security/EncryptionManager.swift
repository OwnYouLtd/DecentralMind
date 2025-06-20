import Foundation
import Security
import CryptoKit

@MainActor
class EncryptionManager: ObservableObject {
    private let masterKeyTag = "com.decentralmind.master.key"
    private let keychainService = "com.decentralmind.encryption"
    private var masterKey: SymmetricKey?

    init() {
        Task {
            await loadOrCreateMasterKey()
        }
    }

    // MARK: - Content Encryption

    func encrypt(string: String?) throws -> Data? {
        guard let masterKey = masterKey, let stringToEncrypt = string else {
            // It's not an error if the string is nil, just return nil.
            return nil
        }
        
        guard let dataToEncrypt = stringToEncrypt.data(using: .utf8) else {
            throw EncryptionError.stringConversionFailed
        }
        
        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: masterKey)
        return sealedBox.combined
    }

    func decrypt(data: Data?) throws -> String? {
        guard let masterKey = masterKey, let encryptedData = data else {
            // It's not an error if the data is nil, just return nil.
            return nil
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: masterKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    // MARK: - Key Management

    private func loadOrCreateMasterKey() async {
        do {
            if let existingKey = try loadMasterKeyFromKeychain() {
                masterKey = existingKey
                print("✅ Master key loaded from keychain.")
                return
            }
            
            let newMasterKey = SymmetricKey(size: .bits256)
            try storeMasterKeyInKeychain(newMasterKey)
            masterKey = newMasterKey
            print("✅ New master key created and stored.")
            
        } catch {
            print("❌ Failed to load or create master key: \(error)")
        }
    }

    private func loadMasterKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: masterKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil // No key found, this is expected on first launch.
        }
        
        guard status == errSecSuccess, let keyData = result as? Data else {
            throw EncryptionError.keychainLoadFailed(status)
        }
        
        return SymmetricKey(data: keyData)
    }

    private func storeMasterKeyInKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: masterKeyTag
        ]
        // It's okay if delete fails (e.g., item not found)
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: masterKeyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw EncryptionError.keychainStoreFailed(status)
        }
    }
}

enum EncryptionError: Error, LocalizedError {
    case noMasterKey
    case stringConversionFailed
    case decryptionFailed
    case keychainStoreFailed(OSStatus)
    case keychainLoadFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noMasterKey: return "Master encryption key is not available."
        case .stringConversionFailed: return "Failed to convert string to data."
        case .decryptionFailed: return "Failed to decrypt data. The key may be incorrect or the data may be corrupt."
        case .keychainStoreFailed(let status): return "Failed to store master key in keychain. Status: \(status)"
        case .keychainLoadFailed(let status): return "Failed to load master key from keychain. Status: \(status)"
        }
    }
}