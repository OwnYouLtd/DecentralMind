import Foundation
import CoreData
import Combine

@MainActor
class DataFlowManager: ObservableObject {
    private let localStorageManager: LocalStorageManager
    private var cancellables = Set<AnyCancellable>()

    @Published var contentEntities: [ContentEntity] = []

    init(context: NSManagedObjectContext) {
        self.localStorageManager = LocalStorageManager(context: context)
        
        // Load initial data from the database
        self.contentEntities = localStorageManager.fetchAllContent()
        
        // Listen for future changes from the database
        localStorageManager.$contentEntities
            .assign(to: \.contentEntities, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Intents
    
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