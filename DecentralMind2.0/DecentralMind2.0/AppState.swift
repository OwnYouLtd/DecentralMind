import Foundation
import Combine
import CoreData

@MainActor
class AppState: ObservableObject {
    let dataFlowManager: DataFlowManager
    let searchIndexManager: SearchIndexManager
    
    @Published var isInitialized = false
    
    // You can add other global app state properties here as needed.

    init(context: NSManagedObjectContext) {
        let dfm = DataFlowManager(context: context)
        self.dataFlowManager = dfm
        self.searchIndexManager = SearchIndexManager(dataFlowManager: dfm)
        // Perform any initial setup for the app's state.
        // For now, we can just mark it as initialized.
        self.isInitialized = true
    }
}