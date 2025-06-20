import Foundation
import CoreData
import Combine

@MainActor
class DataFlowManager: ObservableObject {
    private let localStorageManager: LocalStorageManager
    private var cancellables = Set<AnyCancellable>()

    @Published var contentEntities: [ContentEntity] = []

    // The manager now takes the Core Data context directly.
    init(context: NSManagedObjectContext) {
        // Initialize the local storage manager with the context.
        self.localStorageManager = LocalStorageManager(context: context)
        
        // Establish a pipeline to receive updates from the local storage manager.
        self.localStorageManager.$contentEntities
            .assign(to: \.contentEntities, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Intents (Forwarded to LocalStorageManager)
    
    func createContent(text: String, type: String) {
        localStorageManager.createContent(text: text, type: type)
    }

    func updateContent(_ entity: ContentEntity, with newText: String) {
        localStorageManager.updateContent(entity, with: newText)
    }

    func deleteContent(_ entity: ContentEntity) {
        localStorageManager.deleteContent(entity)
    }
    
    // MARK: - Sync Logic (Placeholder)
    
    func syncWithRemote() async {
        // This is where the new StorachaManager logic will go.
        print("Syncing with remote... (Placeholder)")
    }
}