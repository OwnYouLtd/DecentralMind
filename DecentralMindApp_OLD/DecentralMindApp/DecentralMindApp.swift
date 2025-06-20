import SwiftUI

@main
struct DecentralMindApp: App {
    @StateObject private var appState = AppState()
    
    // The single source of truth for the Core Data stack
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Make the Core Data context available to all views
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // Make the app state available to all views
                .environmentObject(appState)
        }
    }
} 