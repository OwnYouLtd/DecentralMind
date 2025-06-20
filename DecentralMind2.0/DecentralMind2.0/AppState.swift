import Foundation
import Combine
import CoreData

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var isProcessing: Bool = false
    
    let mlxManager: RealMLXManager
    let persistentContainer: NSPersistentContainer
    let dataFlowManager: DataFlowManager
    let localStorageManager: LocalStorageManager
    
    init() {
        print("📱 Initializing AppState...")
        
        // Initialize CoreData
        persistentContainer = PersistenceController.shared.container
        
        // Initialize MLX Manager
        print("📱 Creating RealMLXManager...")
        mlxManager = RealMLXManager()
        
        // Initialize managers
        dataFlowManager = DataFlowManager(
            context: persistentContainer.viewContext,
            mlxManager: mlxManager
        )
        
        localStorageManager = LocalStorageManager(
            context: persistentContainer.viewContext,
            mlxManager: mlxManager
        )
        
        print("✅ AppState initialized successfully")
    }
}