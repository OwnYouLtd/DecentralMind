import SwiftUI

struct CaptureView: View {
    @EnvironmentObject var appState: AppState
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
            .alert("Status", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func processContent() {
        appState.dataFlowManager.createContent(
            text: textInput,
            type: "text/plain" // Default to plain text for this simplified view
        )
        
        // Provide user feedback
        alertMessage = "Content saved successfully!"
        showingAlert = true
        
        // Clear the input
        textInput = ""
    }
}

struct CaptureView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        CaptureView()
            .environmentObject(AppState(context: context))
    }
}