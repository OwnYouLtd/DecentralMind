import Foundation
import CoreData
import Combine

@MainActor
class LocalStorageManager: ObservableObject {
    @Published var contentEntities: [ContentEntity] = []
    
    private let context: NSManagedObjectContext
    private let mlxManager: RealMLXManager?

    init(context: NSManagedObjectContext, mlxManager: RealMLXManager? = nil) {
        self.context = context
        self.mlxManager = mlxManager
        self.contentEntities = fetchAllContent()
    }
    
    func fetchAllContent() -> [ContentEntity] {
        let request = ContentEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ContentEntity.processedAt, ascending: false)]
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch content entities: \(error)")
            return []
        }
    }

    func getContentStats() -> ContentStats {
        let allContent = fetchAllContent()
        let count = allContent.count
        let totalSize = allContent.reduce(0) { (sum, entity) -> Int64 in
            // Estimate size based on original content length in bytes
            let contentSize = Int64(entity.content?.utf8.count ?? 0)
            return sum + contentSize
        }
        return ContentStats(count: count, totalSize: totalSize)
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            self.contentEntities = fetchAllContent() // Refresh the published array
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    func createContent(text: String, type: String) {
        // Create on background context to avoid blocking main thread
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        backgroundContext.perform {
            let newContent = ContentEntity(context: backgroundContext)
            let contentId = UUID()
            newContent.id = contentId
            newContent.content = text
            newContent.contentType = type
            newContent.createdAt = Date()
            newContent.processedAt = Date()
            
            do {
                try backgroundContext.save()
                
                // Update main context on main thread
                DispatchQueue.main.async {
                    do {
                        try self.context.save()
                        self.contentEntities = self.fetchAllContent()
                        
                        // Process with MLX using the main context entity
                        if let mainEntity = self.fetchEntityById(contentId) {
                            Task {
                                await self.processContentWithMLX(mainEntity, text: text, type: type)
                            }
                        }
                    } catch {
                        print("Failed to save to main context: \(error)")
                    }
                }
            } catch {
                print("Failed to save content: \(error)")
            }
        }
    }
    
    private func fetchEntityById(_ id: UUID) -> ContentEntity? {
        let request = ContentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("Failed to fetch entity by ID: \(error)")
            return nil
        }
    }
    
    private func processContentWithMLX(_ entity: ContentEntity, text: String, type: String) async {
        guard let mlxManager = mlxManager else {
            print("⚠️ MLX Manager not available, skipping AI processing")
            // Set basic fallback data on main thread
            await MainActor.run {
                entity.summary = String(text.prefix(100))
                entity.sentiment = "neutral"
                entity.tags = ""
                entity.keyConcepts = ""
                saveContext()
            }
            return
        }
        
        print("🧠 Processing content with MLX: \(text.prefix(50))...")
        
        do {
            // Determine ContentType from string
            let contentType: ContentType
            switch type {
            case "text/plain":
                contentType = .text
            case "note":
                contentType = .note
            case "image/jpeg", "image/png":
                contentType = .image
            default:
                contentType = .text
            }
            
            // Process with MLX
            let result = try await mlxManager.processContent(text, type: contentType)
            
            // Update entity with results on main thread
            await MainActor.run {
                entity.summary = result.summary.isEmpty ? String(text.prefix(100)) : result.summary
                entity.sentiment = result.sentiment.rawValue
                entity.tags = result.tags.joined(separator: ",")
                entity.keyConcepts = result.keyConcepts.joined(separator: ",")
                
                // Convert embedding to Data
                let embeddingData = Data(bytes: result.embedding, count: result.embedding.count * MemoryLayout<Float>.size)
                entity.embedding = embeddingData
                
                entity.processedAt = Date()
                
                // Save the processed result and refresh the UI
                saveContext()
                
                print("✅ Content processed successfully with MLX")
                print("📊 Type: \(result.type), Sentiment: \(result.sentiment), Tags: \(result.tags.joined(separator: ", "))")
                print("📝 Summary: \(result.summary)")
            }
            
        } catch {
            print("❌ Failed to process content with MLX: \(error)")
            // Set fallback data on main thread
            await MainActor.run {
                entity.summary = String(text.prefix(100))
                entity.sentiment = "neutral"
                entity.tags = ""
                entity.keyConcepts = ""
                entity.processedAt = Date()
                saveContext()
            }
        }
    }
    
    func updateContent(_ entity: ContentEntity, with newText: String) {
        entity.content = newText
        saveContext()
        
        // Re-process with MLX if available
        Task {
            await processContentWithMLX(entity, text: newText, type: entity.contentType ?? "text/plain")
        }
    }
    
    func deleteContent(_ entity: ContentEntity) {
        context.delete(entity)
        saveContext()
    }
}
