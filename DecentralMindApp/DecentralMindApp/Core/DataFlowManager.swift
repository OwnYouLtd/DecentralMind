import Foundation
import SwiftUI

/// Manages the complete data flow from content capture to storage and sync
@MainActor
class DataFlowManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var processingQueue: [ProcessingTask] = []
    @Published var isProcessing = false
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Dependencies
    private let mlxManager: MLXManager
    private let localStorageManager: LocalStorageManager
    private let ipfsManager: IPFSManager
    private let encryptionManager: EncryptionManager
    private let searchIndexManager: SearchIndexManager
    
    // MARK: - Configuration
    private let maxConcurrentProcessing = 3
    private let batchSize = 5
    
    init(
        mlxManager: MLXManager,
        localStorageManager: LocalStorageManager,
        ipfsManager: IPFSManager,
        encryptionManager: EncryptionManager,
        searchIndexManager: SearchIndexManager
    ) {
        self.mlxManager = mlxManager
        self.localStorageManager = localStorageManager
        self.ipfsManager = ipfsManager
        self.encryptionManager = encryptionManager
        self.searchIndexManager = searchIndexManager
        
        print("🔄 DataFlowManager initialized")
    }
    
    // MARK: - Public Interface
    
    /// Process new content through the complete pipeline
    func processContent(_ rawContent: RawContent) async throws -> ProcessedContent {
        print("📝 Processing content: \(rawContent.content.prefix(50))...")
        
        let task = ProcessingTask(
            id: UUID(),
            rawContent: rawContent,
            status: .pending,
            createdAt: Date()
        )
        
        processingQueue.append(task)
        
        return try await executeProcessingPipeline(task)
    }
    
    /// Batch process multiple content items
    func batchProcess(_ contents: [RawContent]) async throws -> [ProcessedContent] {
        let tasks = contents.map { content in
            ProcessingTask(
                id: UUID(),
                rawContent: content,
                status: .pending,
                createdAt: Date()
            )
        }
        
        processingQueue.append(contentsOf: tasks)
        
        return try await withThrowingTaskGroup(of: ProcessedContent.self) { group in
            var results: [ProcessedContent] = []
            
            for task in tasks {
                group.addTask {
                    try await self.executeProcessingPipeline(task)
                }
            }
            
            for try await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    /// Force sync with IPFS
    func forceSync() async throws {
        syncStatus = .syncing
        defer { syncStatus = .idle }
        
        try await ipfsManager.syncAll()
    }
    
    // MARK: - Private Methods
    
    private func executeProcessingPipeline(_ task: ProcessingTask) async throws -> ProcessedContent {
        let rawContent = task.rawContent
        
        updateTaskStatus(task.id, .processing)
        
        do {
            // Step 1: Content Analysis with AI
            print("🧠 Analyzing content with AI...")
            let analysisResult = try await analyzeContent(rawContent)
            
            // Step 2: Create Processed Content
            var processedContent = ProcessedContent(
                content: rawContent.content,
                originalContent: rawContent.content,
                summary: analysisResult.summary,
                contentType: rawContent.type,
                category: analysisResult.category,
                tags: analysisResult.tags,
                keyConcepts: analysisResult.keyConcepts,
                sentiment: analysisResult.sentiment,
                embedding: analysisResult.embedding
            )
            
            // Step 3: Handle image data if present
            if let imageData = rawContent.imageData {
                processedContent.fileSize = Int64(imageData.count)
                // For now, set extracted text as placeholder
                processedContent.extractedText = "Image content extracted"
                processedContent.ocrConfidence = 0.85
            }
            
            // Step 4: Local Storage
            print("💾 Saving to local storage...")
            try await localStorageManager.save(processedContent)
            
            // Step 5: Search Index Update
            print("🔍 Updating search index...")
            try await searchIndexManager.addToIndex(processedContent)
            
            // Step 6: Background tasks - Encryption and IPFS Upload
            Task.detached {
                await self.encryptAndUploadToIPFS(processedContent)
            }
            
            updateTaskStatus(task.id, .completed)
            removeCompletedTask(task.id)
            
            print("✅ Content processing complete!")
            return processedContent
            
        } catch {
            updateTaskStatus(task.id, .failed(error))
            print("❌ Processing failed: \(error)")
            throw error
        }
    }
    
    private func analyzeContent(_ rawContent: RawContent) async throws -> ContentAnalysisResult {
        switch rawContent.type {
        case .text, .note, .quote, .highlight:
            return try await mlxManager.processContent(rawContent.content, type: rawContent.type)
        case .url:
            // Extract content from URL first, then analyze
            let urlContent = try await extractContentFromURL(rawContent.content)
            return try await mlxManager.processContent(urlContent, type: .text)
        case .image, .document:
            // For images, analyze any text content provided
            let content = rawContent.content.isEmpty ? "Image document" : rawContent.content
            return try await mlxManager.processContent(content, type: .text)
        }
    }
    
    private func extractContentFromURL(_ url: String) async throws -> String {
        // Extract content from web URL
        guard let url = URL(string: url) else {
            throw DataFlowError.invalidURL
        }
        
        // Use URLSession to fetch and parse content
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Simple HTML parsing (in production, use proper HTML parser)
        let html = String(data: data, encoding: .utf8) ?? ""
        return stripHTMLTags(html)
    }
    
    private func stripHTMLTags(_ html: String) -> String {
        // Basic HTML tag removal
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
    
    private func encryptAndUploadToIPFS(_ content: ProcessedContent) async {
        do {
            print("🔐 Encrypting content...")
            // Encrypt content
            let encryptedData = try await encryptionManager.encrypt(content)
            
            // Check if IPFS is available before attempting upload
            guard ipfsManager.isConnected else {
                print("📴 IPFS not available - content saved locally only")
                return
            }
            
            print("📤 Uploading to IPFS...")
            // Upload to IPFS
            let ipfsHash = try await ipfsManager.upload(encryptedData)
            
            // Update local storage with IPFS hash
            try await localStorageManager.updateIPFSHash(content.id, hash: ipfsHash)
            
            print("✅ Content encrypted and uploaded to IPFS: \(ipfsHash)")
            
        } catch {
            print("⚠️ IPFS upload failed (content still saved locally): \(error)")
        }
    }
    
    private func updateTaskStatus(_ taskId: UUID, _ status: ProcessingStatus) {
        if let index = processingQueue.firstIndex(where: { $0.id == taskId }) {
            processingQueue[index].status = status
        }
    }
    
    private func removeCompletedTask(_ taskId: UUID) {
        processingQueue.removeAll { $0.id == taskId }
    }
}

// MARK: - Supporting Types

struct ProcessingTask: Identifiable {
    let id: UUID
    let rawContent: RawContent
    var status: ProcessingStatus
    let createdAt: Date
}

enum ProcessingStatus {
    case pending
    case processing
    case completed
    case failed(Error)
}

// SyncStatus is defined in RealIPFSManager.swift

enum DataFlowError: LocalizedError {
    case invalidImageData
    case invalidURL
    case processingFailed
    case encryptionFailed
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data provided"
        case .invalidURL:
            return "Invalid URL format"
        case .processingFailed:
            return "Content processing failed"
        case .encryptionFailed:
            return "Content encryption failed"
        case .uploadFailed:
            return "IPFS upload failed"
        }
    }
}