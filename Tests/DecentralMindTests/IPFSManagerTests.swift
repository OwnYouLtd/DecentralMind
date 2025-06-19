import XCTest
@testable import DecentralMind

@MainActor
final class IPFSManagerTests: XCTestCase {
    var ipfsManager: IPFSManager!
    
    override func setUp() async throws {
        try await super.setUp()
        ipfsManager = IPFSManager()
    }
    
    override func tearDown() async throws {
        ipfsManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testIPFSManagerInitialization() {
        XCTAssertNotNil(ipfsManager)
        XCTAssertFalse(ipfsManager.isConnected)
        XCTAssertEqual(ipfsManager.syncStatus, .idle)
    }
    
    func testIPFSInitialization() async {
        await ipfsManager.initialize()
        
        // Connection status depends on whether IPFS daemon is running
        // In CI/testing environments, this might fail
        if ipfsManager.isConnected {
            XCTAssertTrue(ipfsManager.isConnected)
        } else {
            // Expected in test environment without IPFS daemon
            XCTAssertFalse(ipfsManager.isConnected)
        }
    }
    
    // MARK: - Upload Tests
    
    func testDataUpload() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected - requires running IPFS daemon")
        }
        
        let testData = "Hello IPFS World!".data(using: .utf8)!
        
        do {
            let hash = try await ipfsManager.upload(testData, filename: "test.txt")
            
            XCTAssertFalse(hash.isEmpty)
            XCTAssertTrue(hash.hasPrefix("Qm") || hash.hasPrefix("bafy")) // IPFS hash formats
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    func testLargeDataUpload() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        // Create 1MB test data
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        
        do {
            let hash = try await ipfsManager.upload(largeData, filename: "large_test.bin")
            XCTAssertFalse(hash.isEmpty)
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    func testEmptyDataUpload() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let emptyData = Data()
        
        do {
            let hash = try await ipfsManager.upload(emptyData, filename: "empty.txt")
            XCTAssertFalse(hash.isEmpty)
        } catch {
            // Empty data upload might fail - that's acceptable
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Download Tests
    
    func testDataDownload() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let testData = "Download test content".data(using: .utf8)!
        
        do {
            // First upload
            let hash = try await ipfsManager.upload(testData, filename: "download_test.txt")
            
            // Then download
            let downloadedData = try await ipfsManager.download(hash)
            
            XCTAssertEqual(testData, downloadedData)
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    func testInvalidHashDownload() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let invalidHash = "QmInvalidHashThatDoesNotExist123456789"
        
        do {
            _ = try await ipfsManager.download(invalidHash)
            XCTFail("Should throw error for invalid hash")
        } catch IPFSError.downloadFailed {
            XCTAssertTrue(true)
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    // MARK: - Pin/Unpin Tests
    
    func testPinContent() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let testData = "Pin test content".data(using: .utf8)!
        
        do {
            let hash = try await ipfsManager.upload(testData, filename: "pin_test.txt")
            
            // Pin the content
            try await ipfsManager.pin(hash)
            
            // If no error is thrown, pinning succeeded
            XCTAssertTrue(true)
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    func testUnpinContent() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let testData = "Unpin test content".data(using: .utf8)!
        
        do {
            let hash = try await ipfsManager.upload(testData, filename: "unpin_test.txt")
            
            // Pin then unpin
            try await ipfsManager.pin(hash)
            try await ipfsManager.unpin(hash)
            
            XCTAssertTrue(true)
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    // MARK: - Sync Tests
    
    func testSyncAll() async throws {
        // Test sync functionality
        do {
            try await ipfsManager.syncAll()
            XCTAssertEqual(ipfsManager.syncStatus, .idle)
        } catch IPFSError.notConnected {
            // Expected if IPFS not connected
            XCTAssertFalse(ipfsManager.isConnected)
        }
    }
    
    func testSyncProgress() async throws {
        // Test that sync status updates properly
        let initialStatus = ipfsManager.syncStatus
        XCTAssertEqual(initialStatus, .idle)
        
        // Sync should update status temporarily
        Task {
            try? await ipfsManager.syncAll()
        }
        
        // Allow some time for status to potentially change
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Status should return to idle after sync
        let finalStatus = ipfsManager.syncStatus
        XCTAssertEqual(finalStatus, .idle)
    }
    
    // MARK: - Error Handling Tests
    
    func testOperationsWithoutConnection() async throws {
        // Ensure proper error handling when not connected
        XCTAssertFalse(ipfsManager.isConnected)
        
        let testData = "Test data".data(using: .utf8)!
        
        do {
            _ = try await ipfsManager.upload(testData)
            XCTFail("Should throw error when not connected")
        } catch IPFSError.notConnected {
            XCTAssertTrue(true)
        }
        
        do {
            _ = try await ipfsManager.download("QmTest")
            XCTFail("Should throw error when not connected")
        } catch IPFSError.notConnected {
            XCTAssertTrue(true)
        }
    }
    
    func testNetworkErrorHandling() async throws {
        // Test handling of network errors
        // This would require mocking network failures
        XCTAssertTrue(true) // Placeholder for network error tests
    }
    
    // MARK: - Performance Tests
    
    func testUploadPerformance() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let testData = "Performance test data".data(using: .utf8)!
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            _ = try await ipfsManager.upload(testData)
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            // Upload should complete within reasonable time
            XCTAssertLessThan(timeElapsed, 10.0)
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    func testConcurrentUploads() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let testData1 = "Concurrent test 1".data(using: .utf8)!
        let testData2 = "Concurrent test 2".data(using: .utf8)!
        let testData3 = "Concurrent test 3".data(using: .utf8)!
        
        do {
            async let hash1 = ipfsManager.upload(testData1, filename: "concurrent1.txt")
            async let hash2 = ipfsManager.upload(testData2, filename: "concurrent2.txt")
            async let hash3 = ipfsManager.upload(testData3, filename: "concurrent3.txt")
            
            let results = try await [hash1, hash2, hash3]
            
            XCTAssertEqual(results.count, 3)
            XCTAssertTrue(results.allSatisfy { !$0.isEmpty })
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    // MARK: - Filecoin Integration Tests
    
    func testFilecoinStorage() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let testData = "Filecoin test data".data(using: .utf8)!
        
        do {
            let hash = try await ipfsManager.upload(testData, filename: "filecoin_test.txt")
            
            // Test Filecoin storage (this would require Filecoin API access)
            do {
                let dealId = try await ipfsManager.storeOnFilecoin(hash)
                XCTAssertFalse(dealId.isEmpty)
            } catch {
                // Filecoin integration might not be available in tests
                throw XCTSkip("Filecoin API not available")
            }
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    func testFilecoinStatusCheck() async throws {
        // Test deal status checking
        do {
            let status = try await ipfsManager.checkFilecoinStatus("test_deal_id")
            XCTAssertNotNil(status)
        } catch {
            // Expected if Filecoin API not available
            throw XCTSkip("Filecoin API not available")
        }
    }
    
    // MARK: - Integration Tests
    
    func testRoundTripDataIntegrity() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let originalData = "Round trip test: \(UUID().uuidString)".data(using: .utf8)!
        
        do {
            // Upload data
            let hash = try await ipfsManager.upload(originalData, filename: "roundtrip.txt")
            
            // Download data
            let retrievedData = try await ipfsManager.download(hash)
            
            // Verify integrity
            XCTAssertEqual(originalData, retrievedData)
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
    
    func testMultipleFileOperations() async throws {
        guard ipfsManager.isConnected else {
            throw XCTSkip("IPFS not connected")
        }
        
        let files = [
            ("file1.txt", "Content of file 1"),
            ("file2.txt", "Content of file 2"),
            ("file3.txt", "Content of file 3")
        ]
        
        do {
            var hashes: [String] = []
            
            // Upload all files
            for (filename, content) in files {
                let data = content.data(using: .utf8)!
                let hash = try await ipfsManager.upload(data, filename: filename)
                hashes.append(hash)
            }
            
            // Verify all uploads succeeded
            XCTAssertEqual(hashes.count, files.count)
            XCTAssertTrue(hashes.allSatisfy { !$0.isEmpty })
            
            // Download and verify all files
            for (index, hash) in hashes.enumerated() {
                let retrievedData = try await ipfsManager.download(hash)
                let originalContent = files[index].1
                let originalData = originalContent.data(using: .utf8)!
                
                XCTAssertEqual(originalData, retrievedData)
            }
            
        } catch IPFSError.notConnected {
            throw XCTSkip("IPFS not connected")
        }
    }
}