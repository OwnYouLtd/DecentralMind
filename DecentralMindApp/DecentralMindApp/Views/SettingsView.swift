import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            List {
                Section("AI Models") {
                    HStack {
                        Text("MLX Status")
                        Spacer()
                        Text("Ready")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("OCR Status")
                        Spacer()
                        Text("Ready")
                            .foregroundColor(.green)
                    }
                }
                
                Section("Storage") {
                    HStack {
                        Text("Local Storage")
                        Spacer()
                        Text("Active")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("IPFS Connection")
                        Spacer()
                        Text("Connected")
                            .foregroundColor(.green)
                    }
                }
                
                Section("Privacy") {
                    HStack {
                        Text("Encryption")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.green)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}