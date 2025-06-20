import Foundation
import CoreData
import Combine

@MainActor
class LocalStorageManager: ObservableObject {
    @Published var contentEntities: [ContentEntity] = []
    
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
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
        let newContent = ContentEntity(context: context)
        newContent.id = UUID()
        newContent.content = text
        newContent.contentType = type
        newContent.processedAt = Date()
        saveContext()
    }
    
    func updateContent(_ entity: ContentEntity, with newText: String) {
        entity.content = newText
        saveContext()
    }
    
    func deleteContent(_ entity: ContentEntity) {
        context.delete(entity)
        saveContext()
    }
}
