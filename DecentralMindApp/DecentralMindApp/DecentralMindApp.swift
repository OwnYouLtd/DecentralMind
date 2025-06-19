import SwiftUI

@main
struct DecentralMindApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        print("🚀 App launching, initializing AppState...")
        Task {
            await appState.initialize()
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isInitialized = false
    @Published var currentContent: [ProcessedContent] = []
    
    var mlxManager: MLXManager
    var searchIndexManager: SearchIndexManager
    var localStorageManager: LocalStorageManager
    var ipfsManager: IPFSManager
    var encryptionManager: EncryptionManager
    var dataFlowManager: DataFlowManager?
    
    init() {
        print("🔧 AppState init() called - setting up managers...")
        
        print("📱 Creating MLXManager...")
        mlxManager = MLXManager()
        
        print("🔍 Creating SearchIndexManager...")
        searchIndexManager = SearchIndexManager()
        
        print("💾 Creating LocalStorageManager...")
        localStorageManager = LocalStorageManager()
        
        print("🌐 Creating IPFSManager...")
        ipfsManager = IPFSManager()
        
        print("🔐 Creating EncryptionManager...")
        encryptionManager = EncryptionManager()
        
        print("🔄 Creating DataFlowManager...")
        // Create DataFlowManager with all dependencies
        dataFlowManager = DataFlowManager(
            mlxManager: mlxManager,
            localStorageManager: localStorageManager,
            ipfsManager: ipfsManager,
            encryptionManager: encryptionManager,
            searchIndexManager: searchIndexManager
        )
        print("✅ AppState init() completed")
    }
    
    func initialize() async {
        print("🚀 Initializing DecentralMind...")
        
        // Skip model loading for now to avoid performance issues
        // await mlxManager.loadDeepSeekModel()
        print("📱 MLX model loading skipped for performance")
        
        await searchIndexManager.initialize()
        await localStorageManager.initialize()
        await ipfsManager.initialize()
        await encryptionManager.initialize()
        
        isInitialized = true
        print("✅ DecentralMind initialized successfully!")
    }
}