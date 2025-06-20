import Foundation
import CoreData
import Combine

@MainActor
class LocalStorageManager: ObservableObject {
    @Published var contentEntities: [ContentEntity] = []
    
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        fetchAllContent()
    }
    
    func fetchAllContent() {
        let request = ContentEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ContentEntity.createdAt, ascending: false)]
        do {
            contentEntities = try context.fetch(request)
        } catch {
            print("Failed to fetch content entities: \(error)")
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            fetchAllContent()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    func createContent(text: String, type: String) {
        let newContent = ContentEntity(context: context)
        newContent.id = UUID()
        newContent.content = text
        newContent.contentType = type
        newContent.createdAt = Date()
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
