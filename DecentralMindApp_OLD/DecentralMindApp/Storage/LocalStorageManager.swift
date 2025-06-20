import Foundation
import CoreData
import SQLite3

@MainActor
class LocalStorageManager: ObservableObject {
    @Published var isInitialized = false
    
    // Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DecentralMind")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // SQLite FTS5 for full-text search
    private var ftsDatabase: OpaquePointer?
    private let ftsDatabasePath: String
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        ftsDatabasePath = documentsPath.appendingPathComponent("DecentralMind_FTS.db").path
    }
    
    func initialize() async {
        await setupCoreData()
        await setupFTSDatabase()
        isInitialized = true
    }
    
    // MARK: - Content Management
    
    func save(_ content: ProcessedContent) async throws {
        // Save to Core Data
        try await saveToCoreData(content)
        
        // Add to FTS index
        try await addToFTSIndex(content)
    }
    
    func fetch(id: UUID) async throws -> ProcessedContent? {
        let request: NSFetchRequest<ContentEntity> = ContentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let entities = try context.fetch(request)
        return entities.first?.toProcessedContent()
    }
    
    func fetchAll(limit: Int = 100, offset: Int = 0) async throws -> [ProcessedContent] {
        let request: NSFetchRequest<ContentEntity> = ContentEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "processedAt", ascending: false)]
        request.fetchLimit = limit
        request.fetchOffset = offset
        
        let entities = try context.fetch(request)
        return entities.compactMap { $0.toProcessedContent() }
    }
    
    func fetchByCategory(_ category: String) async throws -> [ProcessedContent] {
        let request: NSFetchRequest<ContentEntity> = ContentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [NSSortDescriptor(key: "processedAt", ascending: false)]
        
        let entities = try context.fetch(request)
        return entities.compactMap { $0.toProcessedContent() }
    }
    
    func fetchByTags(_ tags: [String]) async throws -> [ProcessedContent] {
        let predicates = tags.map { NSPredicate(format: "tags CONTAINS %@", $0) }
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        let request: NSFetchRequest<ContentEntity> = ContentEntity.fetchRequest()
        request.predicate = compoundPredicate
        request.sortDescriptors = [NSSortDescriptor(key: "processedAt", ascending: false)]
        
        let entities = try context.fetch(request)
        return entities.compactMap { $0.toProcessedContent() }
    }
    
    func delete(_ content: ProcessedContent) async throws {
        let request: NSFetchRequest<ContentEntity> = ContentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", content.id as CVarArg)
        
        let entities = try context.fetch(request)
        for entity in entities {
            context.delete(entity)
        }
        
        try context.save()
        
        // Remove from FTS index
        try await removeFromFTSIndex(content.id)
    }
    
    func updateIPFSHash(_ contentId: UUID, hash: String) async throws {
        let request: NSFetchRequest<ContentEntity> = ContentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", contentId as CVarArg)
        
        let entities = try context.fetch(request)
        if let entity = entities.first {
            entity.ipfsHash = hash
            try context.save()
        }
    }
    
    // MARK: - Search
    
    func searchContent(_ query: String) async throws -> [ProcessedContent] {
        // Use FTS5 for full-text search
        let ftsResults = try await performFTSSearch(query)
        
        // Fetch full content from Core Data
        let ids = ftsResults.map { UUID(uuidString: $0.id)! }
        return try await fetchByIds(ids)
    }
    
    func semanticSearch(_ embedding: [Float], limit: Int = 20) async throws -> [ProcessedContent] {
        // Vector similarity search
        let allContent = try await fetchAll(limit: 1000) // In production, use vector database
        
        let similarities = allContent.map { content in
            (content: content, similarity: cosineSimilarity(embedding, content.embedding))
        }
        
        let sortedResults = similarities.sorted { $0.similarity > $1.similarity }
        return Array(sortedResults.prefix(limit).map { $0.content })
    }
    
    // MARK: - Statistics
    
    func getContentStats() async throws -> ContentStats {
        let request: NSFetchRequest<ContentEntity> = ContentEntity.fetchRequest()
        let totalCount = try context.count(for: request)
        
        // Get category distribution
        let categoryRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ContentEntity")
        categoryRequest.propertiesToFetch = ["category"]
        categoryRequest.resultType = .dictionaryResultType
        categoryRequest.returnsDistinctResults = true
        
        let categoryResults = try context.fetch(categoryRequest) as! [[String: Any]]
        let categories = categoryResults.compactMap { $0["category"] as? String }
        
        return ContentStats(
            totalItems: totalCount,
            categories: Set(categories),
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupCoreData() async {
        // Core Data model setup would be defined in DecentralMind.xcdatamodeld
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    private func setupFTSDatabase() async {
        let result = sqlite3_open(ftsDatabasePath, &ftsDatabase)
        
        guard result == SQLITE_OK else {
            print("Failed to open FTS database")
            return
        }
        
        // Create FTS5 table
        let createTableSQL = """
            CREATE VIRTUAL TABLE IF NOT EXISTS content_fts USING fts5(
                id,
                content,
                category,
                tags,
                summary,
                key_concepts,
                extracted_text,
                content='',
                contentless_delete=1
            );
        """
        
        sqlite3_exec(ftsDatabase, createTableSQL, nil, nil, nil)
    }
    
    private func saveToCoreData(_ content: ProcessedContent) async throws {
        let entity = ContentEntity(context: context)
        entity.id = content.id
        entity.originalContent = content.originalContent
        entity.contentType = content.contentType.rawValue
        entity.category = content.category
        entity.tags = content.tags.joined(separator: ",")
        entity.summary = content.summary
        entity.keyConcepts = content.keyConcepts.joined(separator: ",")
        entity.sentiment = content.sentiment.rawValue
        entity.processedAt = content.processedAt
        entity.embedding = try JSONEncoder().encode(content.embedding)
        entity.ipfsHash = content.ipfsHash
        entity.isEncrypted = content.isEncrypted
        entity.extractedText = content.extractedText
        entity.ocrConfidence = content.ocrConfidence ?? 0
        entity.detectedLanguage = content.detectedLanguage
        
        try context.save()
    }
    
    private func addToFTSIndex(_ content: ProcessedContent) async throws {
        let insertSQL = """
            INSERT INTO content_fts(id, content, category, tags, summary, key_concepts, extracted_text)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        sqlite3_prepare_v2(ftsDatabase, insertSQL, -1, &statement, nil)
        
        sqlite3_bind_text(statement, 1, content.id.uuidString, -1, nil)
        sqlite3_bind_text(statement, 2, content.originalContent, -1, nil)
        sqlite3_bind_text(statement, 3, content.category, -1, nil)
        sqlite3_bind_text(statement, 4, content.tags.joined(separator: " "), -1, nil)
        sqlite3_bind_text(statement, 5, content.summary, -1, nil)
        sqlite3_bind_text(statement, 6, content.keyConcepts.joined(separator: " "), -1, nil)
        sqlite3_bind_text(statement, 7, content.extractedText ?? "", -1, nil)
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }
    
    private func removeFromFTSIndex(_ contentId: UUID) async throws {
        let deleteSQL = "DELETE FROM content_fts WHERE id = ?;"
        
        var statement: OpaquePointer?
        sqlite3_prepare_v2(ftsDatabase, deleteSQL, -1, &statement, nil)
        sqlite3_bind_text(statement, 1, contentId.uuidString, -1, nil)
        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }
    
    private func performFTSSearch(_ query: String) async throws -> [FTSResult] {
        let searchSQL = "SELECT id, rank FROM content_fts WHERE content_fts MATCH ? ORDER BY rank;"
        
        var statement: OpaquePointer?
        var results: [FTSResult] = []
        
        sqlite3_prepare_v2(ftsDatabase, searchSQL, -1, &statement, nil)
        sqlite3_bind_text(statement, 1, query, -1, nil)
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let rank = sqlite3_column_double(statement, 1)
            
            results.append(FTSResult(id: id, rank: rank))
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    private func fetchByIds(_ ids: [UUID]) async throws -> [ProcessedContent] {
        let request: NSFetchRequest<ContentEntity> = ContentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        
        let entities = try context.fetch(request)
        return entities.compactMap { $0.toProcessedContent() }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    deinit {
        sqlite3_close(ftsDatabase)
    }
}

// MARK: - Supporting Types

struct FTSResult {
    let id: String
    let rank: Double
}

struct ContentStats {
    let totalItems: Int
    let categories: Set<String>
    let lastUpdated: Date
}

// MARK: - Core Data Entity Extension

extension ContentEntity {
    func toProcessedContent() -> ProcessedContent? {
        guard let id = self.id,
              let originalContent = self.originalContent,
              let contentTypeString = self.contentType,
              let contentType = ContentType(rawValue: contentTypeString),
              let category = self.category,
              let summary = self.summary,
              let sentimentString = self.sentiment,
              let sentiment = Sentiment(rawValue: sentimentString),
              let embeddingData = self.embedding,
              let embedding = try? JSONDecoder().decode([Float].self, from: embeddingData) else {
            return nil
        }
        
        let tags = self.tags?.components(separatedBy: ",") ?? []
        let keyConcepts = self.keyConcepts?.components(separatedBy: ",") ?? []
        
        return ProcessedContent(
            id: id,
            originalContent: originalContent,
            contentType: contentType,
            category: category,
            tags: tags,
            summary: summary,
            keyConcepts: keyConcepts,
            sentiment: sentiment,
            processedAt: self.processedAt,
            embedding: embedding,
            ipfsHash: self.ipfsHash,
            isEncrypted: self.isEncrypted,
            extractedText: self.extractedText,
            ocrConfidence: self.ocrConfidence > 0 ? self.ocrConfidence : nil,
            detectedLanguage: self.detectedLanguage
        )
    }
}