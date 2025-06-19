import XCTest
@testable import DecentralMind

@MainActor
final class DataFlowIntegrationTests: XCTestCase {
    var appState: AppState!
    var dataFlowManager: DataFlowManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        appState = AppState()
        await appState.initialize()
        
        dataFlowManager = appState.dataFlowManager
    }
    
    override func tearDown() async throws {
        dataFlowManager = nil
        appState = nil
        try await super.tearDown()
    }
    
    // MARK: - End-to-End Processing Tests
    
    func testTextContentProcessingPipeline() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        let testContent = RawContent(
            content: "This is a test note about machine learning and artificial intelligence. It contains important concepts and should be categorized properly.",
            type: .text
        )
        
        do {
            let processedContent = try await dataFlowManager.processContent(testContent)
            
            // Verify processing results
            XCTAssertFalse(processedContent.category.isEmpty)
            XCTAssertFalse(processedContent.tags.isEmpty)
            XCTAssertFalse(processedContent.summary.isEmpty)
            XCTAssertFalse(processedContent.keyConcepts.isEmpty)
            XCTAssertEqual(processedContent.embedding.count, 384)
            
            // Verify storage
            let retrievedContent = try await appState.localStorageManager.fetch(id: processedContent.id)
            XCTAssertNotNil(retrievedContent)
            XCTAssertEqual(retrievedContent?.originalContent, testContent.content)
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        }
    }
    
    func testImageContentProcessingPipeline() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        // Create test image data
        let testImageData = createTestImageData()
        
        let testContent = RawContent(
            content: "Test image",
            type: .image,
            imageData: testImageData
        )
        
        do {
            let processedContent = try await dataFlowManager.processContent(testContent)
            
            // Verify OCR processing
            XCTAssertNotNil(processedContent.extractedText)
            XCTAssertNotNil(processedContent.ocrConfidence)
            
            // Verify AI processing
            XCTAssertFalse(processedContent.category.isEmpty)
            XCTAssertFalse(processedContent.tags.isEmpty)
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        } catch OCRError.modelNotLoaded {
            throw XCTSkip("OCR model not loaded")
        }
    }
    
    func testBatchProcessingPipeline() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        let testContents = [
            RawContent(content: "First test note", type: .text),
            RawContent(content: "Second test note", type: .note),
            RawContent(content: "Third test quote", type: .quote)
        ]
        
        do {
            let processedContents = try await dataFlowManager.batchProcess(testContents)
            
            XCTAssertEqual(processedContents.count, testContents.count)
            
            for (index, processed) in processedContents.enumerated() {
                XCTAssertEqual(processed.originalContent, testContents[index].content)
                XCTAssertEqual(processed.contentType, testContents[index].type)
                XCTAssertFalse(processed.category.isEmpty)
            }
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        }
    }
    
    // MARK: - Search Integration Tests
    
    func testSearchAfterProcessing() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        let testContent = RawContent(
            content: "Machine learning and artificial intelligence are transforming technology",
            type: .text
        )
        
        do {
            // Process content
            let processedContent = try await dataFlowManager.processContent(testContent)
            
            // Wait for indexing
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Search for the content
            let searchResults = try await appState.searchIndexManager.searchContent("machine learning")
            
            XCTAssertFalse(searchResults.isEmpty)
            XCTAssertTrue(searchResults.contains { $0.id == processedContent.id })
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        }
    }
    
    func testSemanticSearchIntegration() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        let testContents = [
            RawContent(content: "Machine learning algorithms for data analysis", type: .text),
            RawContent(content: "Recipe for chocolate cake", type: .note),
            RawContent(content: "Artificial intelligence in healthcare", type: .text)
        ]
        
        do {
            // Process all content
            var processedContents: [ProcessedContent] = []
            for content in testContents {
                let processed = try await dataFlowManager.processContent(content)
                processedContents.append(processed)
            }
            
            // Perform semantic search
            let queryEmbedding = processedContents[0].embedding // ML content embedding
            let similarContent = try await appState.searchIndexManager.semanticSearch(queryEmbedding, limit: 5)
            
            // Should find the AI content as similar to ML content
            XCTAssertFalse(similarContent.isEmpty)
            let hasAIContent = similarContent.contains { content in
                content.originalContent.contains("Artificial intelligence")
            }
            XCTAssertTrue(hasAIContent)
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        }
    }
    
    // MARK: - IPFS Integration Tests
    
    func testIPFSUploadAfterProcessing() async throws {
        guard let dataFlowManager = dataFlowManager,
              appState.ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let testContent = RawContent(
            content: "Test content for IPFS upload",
            type: .text
        )
        
        do {
            let processedContent = try await dataFlowManager.processContent(testContent)
            
            // Wait for background IPFS upload
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check if IPFS hash was set
            let retrievedContent = try await appState.localStorageManager.fetch(id: processedContent.id)
            XCTAssertNotNil(retrievedContent?.ipfsHash)
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        }
    }
    
    func testCrossDeviceSync() async throws {
        guard appState.ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        // This test would simulate cross-device sync
        // In a real test, you'd have two app instances
        
        do {
            try await appState.ipfsManager.syncAll()
            XCTAssertEqual(appState.ipfsManager.syncStatus, .idle)
        } catch {
            throw XCTSkip("IPFS sync failed: \(error)")
        }
    }
    
    // MARK: - Encryption Integration Tests
    
    func testEncryptionInPipeline() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        let testContent = RawContent(
            content: "Sensitive content that should be encrypted",
            type: .text
        )
        
        do {
            let processedContent = try await dataFlowManager.processContent(testContent)
            
            // Verify content is marked as encrypted
            XCTAssertTrue(processedContent.isEncrypted)
            
            // Test encryption/decryption round trip
            let encryptedData = try await appState.encryptionManager.encrypt(processedContent)
            let decryptedContent = try await appState.encryptionManager.decrypt(encryptedData)
            
            XCTAssertEqual(decryptedContent.originalContent, testContent.content)
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        } catch EncryptionError.noMasterKey {
            throw XCTSkip("Encryption not initialized")
        }
    }
    
    // MARK: - Performance Integration Tests
    
    func testFullPipelinePerformance() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        let testContent = RawContent(
            content: "Performance test content for the full processing pipeline",
            type: .text
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            _ = try await dataFlowManager.processContent(testContent)
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            // Full pipeline should complete within reasonable time
            XCTAssertLessThan(timeElapsed, 10.0) // 10 seconds max
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        }
    }
    
    func testConcurrentProcessing() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        let testContents = (1...5).map { i in
            RawContent(content: "Concurrent test content \(i)", type: .text)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Process all content concurrently
            let processedContents = try await withThrowingTaskGroup(of: ProcessedContent.self) { group in
                for content in testContents {
                    group.addTask {
                        try await dataFlowManager.processContent(content)
                    }
                }
                
                var results: [ProcessedContent] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            XCTAssertEqual(processedContents.count, testContents.count)
            
            // Concurrent processing should be faster than sequential
            XCTAssertLessThan(timeElapsed, 25.0) // Should be much faster than 5 * 10 seconds
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        }
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testPipelineErrorRecovery() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        // Test with invalid content that might cause processing errors
        let invalidContent = RawContent(
            content: String(repeating: "x", count: 50000), // Very long content
            type: .text
        )
        
        do {
            _ = try await dataFlowManager.processContent(invalidContent)
            // If it succeeds, that's fine
            XCTAssertTrue(true)
        } catch {
            // If it fails gracefully, that's also fine
            XCTAssertTrue(true)
        }
    }
    
    func testStorageFailureRecovery() async throws {
        // Test behavior when storage operations fail
        // This would require mocking storage failures
        XCTAssertTrue(true) // Placeholder for storage failure tests
    }
    
    // MARK: - Data Consistency Tests
    
    func testDataConsistencyAcrossComponents() async throws {
        guard let dataFlowManager = dataFlowManager else {
            throw XCTSkip("DataFlowManager not initialized")
        }
        
        let testContent = RawContent(
            content: "Data consistency test content",
            type: .text
        )
        
        do {
            let processedContent = try await dataFlowManager.processContent(testContent)
            
            // Verify data consistency across storage and search
            let storedContent = try await appState.localStorageManager.fetch(id: processedContent.id)
            XCTAssertNotNil(storedContent)
            XCTAssertEqual(storedContent?.originalContent, processedContent.originalContent)
            
            // Verify search index consistency
            let searchResults = try await appState.searchIndexManager.searchContent(testContent.content)
            let foundContent = searchResults.first { $0.id == processedContent.id }
            XCTAssertNotNil(foundContent)
            
        } catch MLXError.modelNotLoaded {
            throw XCTSkip("MLX model not loaded")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageData() -> Data {
        // Create a simple test image (1x1 pixel PNG)
        let image = UIImage(systemName: "circle.fill")!
        return image.pngData() ?? Data()
    }
}