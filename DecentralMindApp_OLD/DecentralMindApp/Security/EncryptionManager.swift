import Foundation
import Security
import CryptoKit
import LocalAuthentication

#if canImport(TargetConditionals)
import TargetConditionals
#endif

@MainActor
class EncryptionManager: ObservableObject {
    @Published var isInitialized = false
    @Published var isBiometricEnabled = false
    
    // Secure Enclave key tag
    private let secureEnclaveKeyTag = "com.decentralmind.secureenclave.key"
    private let masterKeyTag = "com.decentralmind.master.key"
    
    // Keychain service identifier
    private let keychainService = "com.decentralmind.encryption"
    
    private var masterKey: SymmetricKey?
    
    func initialize() async {
        await setupSecureEnclave()
        await loadOrCreateMasterKey()
        isInitialized = true
    }
    
    // MARK: - Content Encryption
    
    func encrypt(_ content: ProcessedContent) async throws -> Data {
        guard let masterKey = masterKey else {
            throw EncryptionError.noMasterKey
        }
        
        // Create codable version of ProcessedContent
        let codableContent = CodableProcessedContent(from: content)
        
        // Serialize content to JSON
        let contentData = try JSONEncoder().encode(codableContent)
        
        // Generate unique key for this content
        let contentKey = SymmetricKey(size: .bits256)
        
        // Encrypt content with unique key
        let encryptedContent = try AES.GCM.seal(contentData, using: contentKey)
        
        // Encrypt the content key with master key
        let keyData = contentKey.withUnsafeBytes { Data($0) }
        let encryptedKey = try AES.GCM.seal(keyData, using: masterKey)
        
        // Create encrypted package
        let package = EncryptedPackage(
            encryptedContent: encryptedContent.combined!,
            encryptedKey: encryptedKey.combined!,
            metadata: EncryptionMetadata(
                algorithm: "AES-GCM-256",
                version: 1,
                timestamp: Date()
            )
        )
        
        return try JSONEncoder().encode(package)
    }
    
    func decrypt(_ encryptedData: Data) async throws -> ProcessedContent {
        guard let masterKey = masterKey else {
            throw EncryptionError.noMasterKey
        }
        
        // Decode encrypted package
        let package = try JSONDecoder().decode(EncryptedPackage.self, from: encryptedData)
        
        // Decrypt content key
        let encryptedKey = try AES.GCM.SealedBox(combined: package.encryptedKey)
        let keyData = try AES.GCM.open(encryptedKey, using: masterKey)
        let contentKey = SymmetricKey(data: keyData)
        
        // Decrypt content
        let encryptedContent = try AES.GCM.SealedBox(combined: package.encryptedContent)
        let contentData = try AES.GCM.open(encryptedContent, using: contentKey)
        
        // Deserialize content
        let codableContent = try JSONDecoder().decode(CodableProcessedContent.self, from: contentData)
        return codableContent.toProcessedContent()
    }
    
    // MARK: - Key Management
    
    func rotateKeys() async throws {
        // Generate new master key
        let newMasterKey = SymmetricKey(size: .bits256)
        
        // Re-encrypt all content with new key
        // This would be implemented to fetch all encrypted content,
        // decrypt with old key, and encrypt with new key
        
        // Store new master key
        try await storeMasterKey(newMasterKey)
        masterKey = newMasterKey
    }
    
    func authenticateUser() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw EncryptionError.biometricNotAvailable
        }
        
        let reason = "Authenticate to access your encrypted content"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            throw EncryptionError.authenticationFailed
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSecureEnclave() async {
        // Check if Secure Enclave is available
        guard SecureEnclave.isAvailable else {
            print("Secure Enclave not available on this device")
            return
        }
        
        // Create or load Secure Enclave key
        do {
            try await createSecureEnclaveKey()
            isBiometricEnabled = true
        } catch {
            print("Failed to setup Secure Enclave: \(error)")
        }
    }
    
    private func createSecureEnclaveKey() async throws {
        let flags: SecAccessControlCreateFlags = [
            .privateKeyUsage,
            .biometryCurrentSet
        ]
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            nil
        ) else {
            throw EncryptionError.secureEnclaveSetupFailed
        }
        
        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: secureEnclaveKeyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: accessControl
            ]
        ]
        
        // Attempt to create key in Secure Enclave; error details are not retained
        guard SecKeyCreateRandomKey(keyAttributes as CFDictionary, nil) != nil else {
            throw EncryptionError.secureEnclaveSetupFailed
        }
    }
    
    private func loadOrCreateMasterKey() async {
        do {
            // Try to load existing master key
            if let existingKey = try loadMasterKeyFromKeychain() {
                masterKey = existingKey
                return
            }
            
            // Create new master key if none exists
            let newMasterKey = SymmetricKey(size: .bits256)
            try await storeMasterKey(newMasterKey)
            masterKey = newMasterKey
            
        } catch {
            print("Failed to load/create master key: \(error)")
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
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
    
    private func storeMasterKey(_ key: SymmetricKey) async throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Delete existing key if any
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: masterKeyTag
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Store new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: masterKeyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw EncryptionError.keychainStoreFailed
        }
    }
    
    private func getSecureEnclaveKey() throws -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: secureEnclaveKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return (item as! SecKey)
    }
}

// MARK: - Supporting Types

struct EncryptedPackage: Codable {
    let encryptedContent: Data
    let encryptedKey: Data
    let metadata: EncryptionMetadata
}

struct EncryptionMetadata: Codable {
    let algorithm: String
    let version: Int
    let timestamp: Date
}

enum EncryptionError: LocalizedError {
    case noMasterKey
    case biometricNotAvailable
    case authenticationFailed
    case secureEnclaveSetupFailed
    case keychainStoreFailed
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .noMasterKey:
            return "No master encryption key available"
        case .biometricNotAvailable:
            return "Biometric authentication not available"
        case .authenticationFailed:
            return "User authentication failed"
        case .secureEnclaveSetupFailed:
            return "Failed to setup Secure Enclave"
        case .keychainStoreFailed:
            return "Failed to store key in Keychain"
        case .encryptionFailed:
            return "Content encryption failed"
        case .decryptionFailed:
            return "Content decryption failed"
        }
    }
}

// MARK: - Secure Enclave Helper

extension SecureEnclave {
    static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        #endif
    }
}

// MARK: - Codable ProcessedContent

struct CodableProcessedContent: Codable {
    let id: UUID
    let content: String
    let metadataJSON: String
    let originalContent: String
    let summary: String
    let contentType: String
    let processedAt: Date
    let category: String
    let tags: [String]
    let keyConcepts: [String]
    let sentiment: String
    let embedding: [Float]
    let ipfsHash: String?
    let isEncrypted: Bool
    let extractedText: String?
    let ocrConfidence: Float?
    let detectedLanguage: String?
    
    init(from content: ProcessedContent) {
        self.id = content.id
        self.content = content.content
        self.originalContent = content.originalContent
        self.summary = content.summary
        self.contentType = content.contentType.rawValue
        self.processedAt = content.processedAt
        self.category = content.category
        self.tags = content.tags
        self.keyConcepts = content.keyConcepts
        self.sentiment = content.sentiment.rawValue
        self.embedding = content.embedding
        self.ipfsHash = content.ipfsHash
        self.isEncrypted = content.isEncrypted
        self.extractedText = content.extractedText
        self.ocrConfidence = content.ocrConfidence
        self.detectedLanguage = content.detectedLanguage
        
        // Create metadata JSON from content properties
        let metadata: [String: Any] = [
            "sourceURL": content.sourceURL ?? NSNull(),
            "fileSize": content.fileSize ?? NSNull(),
            "imageMetadata": content.imageMetadata?.toDictionary() ?? NSNull()
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.metadataJSON = jsonString
        } else {
            self.metadataJSON = "{}"
        }
    }
    
    func toProcessedContent() -> ProcessedContent {
        // Convert JSON string back to metadata
        var sourceURL: String?
        var fileSize: Int64?
        var imageMetadata: ImageMetadata?
        
        if let jsonData = metadataJSON.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            sourceURL = dict["sourceURL"] as? String
            fileSize = dict["fileSize"] as? Int64
            if let imageDict = dict["imageMetadata"] as? [String: Any] {
                imageMetadata = ImageMetadata.fromDictionary(imageDict)
            }
        }
        
        return ProcessedContent(
            id: id,
            content: content,
            originalContent: originalContent,
            summary: summary,
            contentType: ContentType(rawValue: contentType) ?? .text,
            category: category,
            tags: tags,
            keyConcepts: keyConcepts,
            sentiment: Sentiment(rawValue: sentiment) ?? .neutral,
            embedding: embedding,
            ipfsHash: ipfsHash,
            isEncrypted: isEncrypted,
            extractedText: extractedText,
            ocrConfidence: ocrConfidence,
            detectedLanguage: detectedLanguage,
            sourceURL: sourceURL,
            fileSize: fileSize,
            imageMetadata: imageMetadata
        )
    }
}