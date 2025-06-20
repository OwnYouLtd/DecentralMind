import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var customPrompt = UserDefaults.standard.string(forKey: "mlx_custom_prompt") ?? "Analyze this content and provide: 1) A brief summary, 2) Key concepts, 3) Sentiment analysis, 4) Relevant tags"
    @State private var isEditingPrompt = false
    
    var body: some View {
        NavigationView {
            List {
                Section("AI Processing") {
                    HStack {
                        Text("MLX Status")
                        Spacer()
                        Text(appState.mlxManager.isModelLoaded ? "Ready" : "Initializing")
                            .foregroundColor(appState.mlxManager.isModelLoaded ? .green : .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Custom Prompt")
                            Spacer()
                            Button(isEditingPrompt ? "Save" : "Edit") {
                                if isEditingPrompt {
                                    UserDefaults.standard.set(customPrompt, forKey: "mlx_custom_prompt")
                                    appState.mlxManager.updatePrompt(customPrompt)
                                }
                                isEditingPrompt.toggle()
                            }
                            .foregroundColor(.blue)
                        }
                        
                        if isEditingPrompt {
                            TextEditor(text: $customPrompt)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        } else {
                            Text(customPrompt)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Model Status") {
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}