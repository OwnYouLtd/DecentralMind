//
//  DecentralMind2_0App.swift
//  DecentralMind2.0
//
//  Created by Nicholas Longcroft on 19/06/2025.
//

import SwiftUI

@main
struct DecentralMind2_0App: App {
    @StateObject private var appState: AppState
    private let persistenceController = PersistenceController.shared

    init() {
        let context = persistenceController.container.viewContext
        _appState = StateObject(wrappedValue: AppState(context: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
