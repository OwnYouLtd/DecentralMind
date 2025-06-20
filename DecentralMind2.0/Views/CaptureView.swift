import SwiftUI

struct CaptureView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var textInput = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Add New Content")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                TextEditor(text: $textInput)
                    .frame(minHeight: 200)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )

                Button(action: processContent) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Save Content")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(textInput.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(textInput.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Status", isPresented: $showingAlert) {
                Button("OK") { 
                    dismiss() // Dismiss after user acknowledges the save
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func processContent() {
        print("🔵 Save button pressed with text: '\(textInput)'")
        print("🔵 AppState available: \(appState)")
        print("🔵 DataFlowManager available: \(appState.dataFlowManager)")
        
        // Store the text before clearing it
        let textToSave = textInput
        
        // Clear the input immediately for better UX
        textInput = ""
        
        // Show immediate feedback
        alertMessage = "Saving content..."
        showingAlert = false // Don't show alert yet
        
        // Perform the save operation asynchronously
        Task {
            do {
                appState.dataFlowManager.createContent(
                    text: textToSave,
                    type: "text/plain"
                )
                
                print("✅ Content creation called successfully")
                
                // Update UI on main thread
                await MainActor.run {
                    alertMessage = "Content saved successfully!"
                    showingAlert = true
                }
            } catch {
                print("❌ Error creating content: \(error)")
                await MainActor.run {
                    alertMessage = "Failed to save content: \(error.localizedDescription)"
                    showingAlert = true
                    // Restore text if save failed
                    textInput = textToSave
                }
            }
        }
    }
}

struct CaptureView_Previews: PreviewProvider {
    static var previews: some View {
        CaptureView()
            .environmentObject(AppState())
    }
}