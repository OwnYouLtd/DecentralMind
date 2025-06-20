import Foundation
import CoreData
import Combine

@MainActor
class DataFlowManager: ObservableObject {
    private let localStorageManager: LocalStorageManager
    private var cancellables = Set<AnyCancellable>()

    @Published var contentEntities: [ContentEntity] = []

    // The manager now takes the Core Data context and MLXManager directly.
    init(context: NSManagedObjectContext, mlxManager: RealMLXManager? = nil) {
        // Initialize the local storage manager with the context and MLX manager.
        self.localStorageManager = LocalStorageManager(context: context, mlxManager: mlxManager)
        
        // Establish a pipeline to receive updates from the local storage manager.
        self.localStorageManager.$contentEntities
            .assign(to: \.contentEntities, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Data Access
    
    func fetchAllContent() -> [ContentEntity] {
        return localStorageManager.fetchAllContent()
    }

    func getContentStats() -> ContentStats {
        return localStorageManager.getContentStats()
    }

    // MARK: - Intents (Forwarded to LocalStorageManager)
    
    func createContent(text: String, type: String) {
        localStorageManager.createContent(text: text, type: type)
        refreshContent()
    }

    func updateContent(_ entity: ContentEntity, with newText: String) {
        localStorageManager.updateContent(entity, with: newText)
        refreshContent()
    }

    func deleteContent(_ entity: ContentEntity) {
        localStorageManager.deleteContent(entity)
        refreshContent()
    }

    // A helper method to manually refresh the published content array.
    private func refreshContent() {
        self.contentEntities = localStorageManager.fetchAllContent()
    }
    
    // MARK: - Sync Logic (Placeholder)
    
    func syncWithRemote() async {
        // This is where the new StorachaManager logic will go.
        print("Syncing with remote... (Placeholder)")
    }
}