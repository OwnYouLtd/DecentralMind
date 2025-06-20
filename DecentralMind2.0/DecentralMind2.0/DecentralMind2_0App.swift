//
//  DecentralMind2_0App.swift
//  DecentralMind2.0
//
//  Created by Nicholas Longcroft on 19/06/2025.
//

import SwiftUI

@main
struct DecentralMind2_0App: App {
    @State private var appState: AppState?
    @State private var initializationError: String?
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if let appState = appState {
                    ContentView()
                        .environmentObject(appState)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else if let error = initializationError {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("Initialization Error")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(error)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Retry") {
                            initializeApp()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Initializing DecentralMind...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                initializeApp()
            }
        }
    }
    
    private func initializeApp() {
        Task {
            do {
                let context = persistenceController.container.viewContext
                let newAppState = AppState()
                
                await MainActor.run {
                    self.appState = newAppState
                    self.initializationError = nil
                }
            } catch {
                await MainActor.run {
                    self.initializationError = "Failed to initialize: \(error.localizedDescription)"
                }
            }
        }
    }
}
