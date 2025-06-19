import Foundation
import Combine
import MLX

/// Manages the complete data flow from content capture to storage and sync
@MainActor
class DataFlowManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var processingQueue: [ProcessingTask] = []
    @Published var isProcessing = false
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Dependencies
    private let mlxManager: MLXManager
    private let ocrManager: GOTOCRManager
    private let localStorageManager: LocalStorageManager
    private let ipfsManager: IPFSManager
    private let encryptionManager: EncryptionManager
    private let searchIndexManager: SearchIndexManager
    
    // MARK: - Configuration
    private let maxConcurrentProcessing = 3
    private let batchSize = 5
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init(
        mlxManager: MLXManager,
        ocrManager: GOTOCRManager,
        localStorageManager: LocalStorageManager,
        ipfsManager: IPFSManager,
        encryptionManager: EncryptionManager,
        searchIndexManager: SearchIndexManager
    ) {
        self.mlxManager = mlxManager
        self.ocrManager = ocrManager
        self.localStorageManager = localStorageManager
        self.ipfsManager = ipfsManager
        self.encryptionManager = encryptionManager
        self.searchIndexManager = searchIndexManager
        
        setupDataFlowPipeline()
    }
    
    // MARK: - Public Interface
    
    /// Process new content through the complete pipeline
    func processContent(_ rawContent: RawContent) async throws -> ProcessedContent {
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
    
    private func setupDataFlowPipeline() {
        // Monitor processing queue changes
        $processingQueue
            .sink { [weak self] queue in
                Task { @MainActor in
                    self?.processQueueIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        // Monitor sync status
        ipfsManager.$syncStatus
            .assign(to: \.syncStatus, on: self)
            .store(in: &cancellables)
    }
    
    private func processQueueIfNeeded() {
        let pendingTasks = processingQueue.filter { $0.status == .pending }
        let processingTasks = processingQueue.filter { $0.status == .processing }
        
        if processingTasks.count < maxConcurrentProcessing && !pendingTasks.isEmpty {
            let tasksToProcess = Array(pendingTasks.prefix(maxConcurrentProcessing - processingTasks.count))
            
            for task in tasksToProcess {
                Task {
                    await processTask(task)
                }
            }
        }
    }
    
    private func processTask(_ task: ProcessingTask) async {
        updateTaskStatus(task.id, .processing)
        
        do {
            let result = try await executeProcessingPipeline(task)
            updateTaskStatus(task.id, .completed)
            removeCompletedTask(task.id)
        } catch {
            updateTaskStatus(task.id, .failed(error))
            print("Processing failed for task \(task.id): \(error)")
        }
    }
    
    private func executeProcessingPipeline(_ task: ProcessingTask) async throws -> ProcessedContent {
        let rawContent = task.rawContent
        
        // Step 1: Content Analysis with DeepSeek-R1
        let analysisResult = try await analyzeContent(rawContent)
        
        // Step 2: OCR Processing (if image content)
        let ocrResult = try await performOCRIfNeeded(rawContent)
        
        // Step 3: Create Processed Content
        var processedContent = ProcessedContent(
            id: UUID(),
            originalContent: rawContent.content,
            contentType: rawContent.type,
            category: analysisResult.category,
            tags: analysisResult.tags,
            summary: analysisResult.summary,
            keyConcepts: analysisResult.keyConcepts,
            sentiment: analysisResult.sentiment,
            processedAt: Date(),
            embedding: analysisResult.embedding
        )
        
        // Add OCR data if available
        if let ocr = ocrResult {
            processedContent.extractedText = ocr.text
            processedContent.ocrConfidence = ocr.confidence
            processedContent.detectedLanguage = ocr.detectedLanguage
        }
        
        // Step 4: Local Storage
        try await localStorageManager.save(processedContent)
        
        // Step 5: Search Index Update
        try await searchIndexManager.addToIndex(processedContent)
        
        // Step 6: Encryption and IPFS Upload (background)
        Task.detached {
            await self.encryptAndUploadToIPFS(processedContent)
        }
        
        return processedContent
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
            // OCR first, then analyze extracted text
            if let imageData = rawContent.imageData {
                let ocrResult = try await ocrManager.extractText(from: UIImage(data: imageData)!)
                return try await mlxManager.processContent(ocrResult.text, type: .text)
            } else {
                throw DataFlowError.invalidImageData
            }
        }
    }
    
    private func performOCRIfNeeded(_ rawContent: RawContent) async throws -> OCRResult? {
        switch rawContent.type {
        case .image, .document:
            guard let imageData = rawContent.imageData,
                  let image = UIImage(data: imageData) else {
                throw DataFlowError.invalidImageData
            }
            return try await ocrManager.extractText(from: image)
        default:
            return nil
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
        // Basic HTML tag removal (use proper parser in production)
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
    
    private func encryptAndUploadToIPFS(_ content: ProcessedContent) async {
        do {
            // Encrypt content
            let encryptedData = try await encryptionManager.encrypt(content)
            
            // Upload to IPFS
            let ipfsHash = try await ipfsManager.upload(encryptedData)
            
            // Update local storage with IPFS hash
            try await localStorageManager.updateIPFSHash(content.id, hash: ipfsHash)
            
        } catch {
            print("Failed to encrypt and upload to IPFS: \(error)")
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

struct RawContent {
    let content: String
    let type: ContentType
    let imageData: Data?
    let metadata: [String: Any]
    
    init(content: String, type: ContentType, imageData: Data? = nil, metadata: [String: Any] = [:]) {
        self.content = content
        self.type = type
        self.imageData = imageData
        self.metadata = metadata
    }
}

struct ContentAnalysisResult {
    let category: String
    let tags: [String]
    let summary: String
    let keyConcepts: [String]
    let sentiment: Sentiment
    let embedding: [Float]
}

enum ProcessingStatus {
    case pending
    case processing
    case completed
    case failed(Error)
}

enum SyncStatus {
    case idle
    case syncing
    case error(Error)
}

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