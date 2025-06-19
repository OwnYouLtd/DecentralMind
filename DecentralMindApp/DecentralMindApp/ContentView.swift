import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        if appState.isInitialized {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                
                CaptureView()
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text("Capture")
                    }
                    .tag(1)
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(3)
            }
            .accentColor(.purple)
        } else {
            InitializationView()
        }
    }
}

struct InitializationView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            // App Logo/Icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.purple)
            
            Text("DecentralMind")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Privacy-first AI note taking")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    .scaleEffect(1.5)
                
                Text("Initializing DecentralMind...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}