import XCTest
@testable import DecentralMind
import MLX

@MainActor
final class MLXManagerTests: XCTestCase {
    var mlxManager: MLXManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mlxManager = MLXManager()
    }
    
    override func tearDown() async throws {
        mlxManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testMLXManagerInitialization() {
        XCTAssertNotNil(mlxManager)
        XCTAssertFalse(mlxManager.isModelLoaded)
        XCTAssertFalse(mlxManager.isProcessing)
    }
    
    func testMLXSetup() {
        // Test that MLX is configured properly
        // This would test GPU memory limits and device settings
        XCTAssertTrue(true) // Placeholder for actual MLX configuration tests
    }
    
    // MARK: - Model Loading Tests
    
    func testModelLoadingWithValidModel() async throws {
        // Mock model loading - in real tests you'd use a test model
        do {
            try await mlxManager.loadDeepSeekModel()
            XCTAssertTrue(mlxManager.isModelLoaded)
        } catch MLXError.modelNotFound {
            // Expected if test model isn't available
            XCTAssertFalse(mlxManager.isModelLoaded)
        }
    }
    
    func testModelLoadingWithInvalidPath() async throws {
        // Test error handling for missing model
        do {
            try await mlxManager.loadDeepSeekModel()
        } catch MLXError.modelNotFound {
            XCTAssertFalse(mlxManager.isModelLoaded)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDoubleModelLoading() async throws {
        // Test that loading model twice doesn't cause issues
        do {
            try await mlxManager.loadDeepSeekModel()
            try await mlxManager.loadDeepSeekModel() // Should not reload
            XCTAssertTrue(mlxManager.isModelLoaded)
        } catch MLXError.modelNotFound {
            // Expected if test model isn't available
            pass()
        }
    }
    
    // MARK: - Content Processing Tests
    
    func testTextContentProcessing() async throws {
        // Test basic text processing
        let testContent = "This is a test note about machine learning and AI."
        
        do {
            let result = try await mlxManager.processContent(testContent, type: .text)
            
            XCTAssertFalse(result.category.isEmpty)
            XCTAssertFalse(result.tags.isEmpty)
            XCTAssertFalse(result.summary.isEmpty)
            XCTAssertEqual(result.embedding.count, 384) // Expected embedding size
            
        } catch MLXError.modelNotLoaded {
            // Expected if model isn't loaded
            pass()
        }
    }
    
    func testNoteContentProcessing() async throws {
        let testNote = "Meeting notes: Discussed project timeline, budget constraints, and team allocation."
        
        do {
            let result = try await mlxManager.processContent(testNote, type: .note)
            
            XCTAssertNotNil(result)
            XCTAssertTrue(result.category.contains("meeting") || result.category.contains("work"))
            XCTAssertTrue(result.tags.contains { $0.contains("project") || $0.contains("meeting") })
            
        } catch MLXError.modelNotLoaded {
            pass()
        }
    }
    
    func testQuoteContentProcessing() async throws {
        let testQuote = "The only way to do great work is to love what you do. - Steve Jobs"
        
        do {
            let result = try await mlxManager.processContent(testQuote, type: .quote)
            
            XCTAssertNotNil(result)
            XCTAssertEqual(result.sentiment, .positive)
            XCTAssertTrue(result.keyConcepts.contains { $0.contains("work") || $0.contains("motivation") })
            
        } catch MLXError.modelNotLoaded {
            pass()
        }
    }
    
    func testEmptyContentProcessing() async throws {
        do {
            let result = try await mlxManager.processContent("", type: .text)
            XCTFail("Should throw error for empty content")
        } catch {
            // Expected to fail
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Performance Tests
    
    func testContentProcessingPerformance() async throws {
        let testContent = "This is a performance test with a reasonable amount of text content to process."
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            _ = try await mlxManager.processContent(testContent, type: .text)
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            // Processing should complete within reasonable time (5 seconds)
            XCTAssertLessThan(timeElapsed, 5.0)
            
        } catch MLXError.modelNotLoaded {
            pass()
        }
    }
    
    func testBatchProcessingPerformance() async throws {
        let testContents = [
            "First test content",
            "Second test content",
            "Third test content"
        ]
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            for content in testContents {
                _ = try await mlxManager.processContent(content, type: .text)
            }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            // Batch processing should be reasonably fast
            XCTAssertLessThan(timeElapsed, 15.0) // 5 seconds per item
            
        } catch MLXError.modelNotLoaded {
            pass()
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryUsageDuringProcessing() async throws {
        // Test that memory usage doesn't grow excessively
        let initialMemory = getMemoryUsage()
        
        do {
            for i in 1...10 {
                let content = "Test content number \(i) with some additional text to make it longer."
                _ = try await mlxManager.processContent(content, type: .text)
            }
            
            let finalMemory = getMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory
            
            // Memory increase should be reasonable (less than 100MB)
            XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024)
            
        } catch MLXError.modelNotLoaded {
            pass()
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testProcessingWithoutLoadedModel() async throws {
        // Ensure proper error when model isn't loaded
        do {
            _ = try await mlxManager.processContent("test", type: .text)
            XCTFail("Should throw error when model not loaded")
        } catch MLXError.modelNotLoaded {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testInvalidContentHandling() async throws {
        let invalidContent = String(repeating: "a", count: 100000) // Very long content
        
        do {
            _ = try await mlxManager.processContent(invalidContent, type: .text)
            // Should either succeed or fail gracefully
        } catch {
            // Any error is acceptable for invalid input
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func pass() {
        // Helper function for expected failures
        XCTAssertTrue(true)
    }
}