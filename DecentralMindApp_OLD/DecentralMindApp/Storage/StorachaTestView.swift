import SwiftUI

struct StorachaTestView: View {
    @StateObject private var storachaManager = StorachaManager()
    @State private var email: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Storacha WebView Bridge Test")
                .font(.title)

            if !storachaManager.isReady {
                ProgressView()
                Text("Initializing WebView Bridge...")
                    .foregroundColor(.secondary)
            } else {
                Text("Bridge Ready ✅")
                    .foregroundColor(.green)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Status:")
                    .font(.headline)
                Text(" • Authenticating: \(storachaManager.isAuthenticating ? "⏳" : "No")")
                Text(" • Authenticated: \(storachaManager.isAuthenticated ? "✅" : "❌")")
                Text(" • User DID: \(storachaManager.userDID ?? "N/A")")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)


            Divider()
            
            if storachaManager.isReady && !storachaManager.isAuthenticated {
                VStack(spacing: 12) {
                     Text("Enter your email to authenticate with Storacha. You will need to click the link sent to your inbox to complete the process.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button("Login with Email") {
                        Task {
                            await authenticate()
                        }
                    }
                    .disabled(email.isEmpty || storachaManager.isAuthenticating)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            // The manager is already initialized
        }
    }

    private func authenticate() async {
        do {
            try await storachaManager.authenticate(email: email)
            print("Authentication flow completed successfully in the view.")
        } catch {
            print("Authentication flow failed in the view: \(error.localizedDescription)")
            // Optionally, show an alert to the user
        }
    }
}

struct StorachaTestView_Previews: PreviewProvider {
    static var previews: some View {
        StorachaTestView()
    }
} 