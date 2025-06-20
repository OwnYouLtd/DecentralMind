import Foundation
import WebKit

// MARK: - Custom Errors
enum StorachaError: Error, LocalizedError {
    case notAuthenticated
    case uploadFailed(String?)
    case invalidResponse
    case invalidURL
    case webViewError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Storacha."
        case .uploadFailed(let reason):
            return "Storacha upload failed. Reason: \(reason ?? "Unknown")"
        case .invalidResponse:
            return "Received an invalid response from Storacha."
        case .invalidURL:
            return "The URL for the Storacha request is invalid."
        case .webViewError(let message):
            return "WebView bridge error: \(message)"
        }
    }
}

// MARK: - Main StorachaManager Class
@MainActor
class StorachaManager: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var isAuthenticating = false
    @Published var isAuthenticated = false
    @Published var userDID: String?

    private var webView: WKWebView!
    private var authenticationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        setupWebView()
    }

    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "bridge")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        
        // This is a common technique to ensure the WebView is part of the view hierarchy and executes JavaScript.
        // It's added to the key window but remains invisible (zero frame).
        DispatchQueue.main.async {
            if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) {
                window.addSubview(self.webView)
            } else {
                 print("Warning: Could not find a key window to attach the WebView to. The bridge may not function correctly. Retrying in 1s.")
                 DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                      // We only want to set up the WebView once.
                      // If it's already created, just try adding it to the window again.
                     if self.webView != nil {
                        if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) {
                            window.addSubview(self.webView)
                        }
                     } else {
                        self.setupWebView()
                     }
                 }
            }
        }
        
        if let url = Bundle.main.url(forResource: "bridge", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            print("CRITICAL ERROR: bridge.html not found. Make sure it's added to the project and target.")
        }
    }

    // MARK: - Authentication
    
    private func checkExistingAuthorization() {
        guard isReady else { return }
        print("Checking for existing authorization...")
        let script = "window.w3up.checkAuthorization();"
        self.webView.evaluateJavaScript(script)
    }

    func authenticate(email: String) async throws {
        guard isReady else {
            throw StorachaError.webViewError("WebView is not ready. Please try again.")
        }
        
        if isAuthenticating {
            print("Authentication is already in progress.")
            // You might want to throw an error or handle this differently
            return
        }
        
        isAuthenticating = true
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.authenticationContinuation = continuation
            let script = "window.w3up.authorize('\\(email)');"
            self.webView.evaluateJavaScript(script) { _, _ in
                // JavaScript execution errors are handled via the message handler
                // Do not resume successfully here. Wait for the 'authorized_successfully' message.
            }
        }
    }

    // MARK: - Core Storacha Operations (Phase 2)
    
    func upload(data: Data, filename: String) async throws -> String {
        guard isAuthenticated, let _ = userDID else {
            throw StorachaError.notAuthenticated
        }
        // We will implement this in Phase 2
        print("🚀 Uploading \(filename) to Storacha... (Placeholder)")
        let placeholderCID = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        return placeholderCID
    }
}

// MARK: - WK Delegates
extension StorachaManager: WKNavigationDelegate, WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "bridge", let body = message.body as? [String: Any] else { return }
        guard let status = body["status"] as? String else { return }

        switch status {
        case "initialized":
            print("✅ Storacha WebView bridge initialized.")
            self.isReady = true
            checkExistingAuthorization()

        case "authorization_started":
            print("📬 Authorization process started. Awaiting user action in browser.")
            
        case "authorized_successfully":
            print("✅ Authorization successful!")
            if let did = body["did"] as? String {
                self.userDID = did
                self.isAuthenticated = true
                print("Authenticated with DID: \\(did)")
            }
            authenticationContinuation?.resume()
            authenticationContinuation = nil
            self.isAuthenticating = false
        
        case "not_authorized":
            print("User is not currently authorized.")
            self.isAuthenticated = false
            self.userDID = nil

        case "error":
            let errorMessage = body["message"] as? String ?? "Unknown WebView error"
            print("🛑 Storacha WebView Bridge Error: \\(errorMessage)")
            authenticationContinuation?.resume(throwing: StorachaError.webViewError(errorMessage))
            authenticationContinuation = nil
            self.isAuthenticating = false

        default:
            print("Received unknown message from WebView: \\(body)")
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView finished loading bridge.html. The JS client is now initializing.")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("🛑 WebView failed to load local HTML: \\(error.localizedDescription)")
        authenticationContinuation?.resume(throwing: StorachaError.webViewError("WebView failed to load: \\(error.localizedDescription)"))
        authenticationContinuation = nil
        self.isAuthenticating = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("🛑 WebView failed provisional navigation: \\(error.localizedDescription)")
        authenticationContinuation?.resume(throwing: StorachaError.webViewError("WebView failed provisional navigation: \\(error.localizedDescription)"))
        authenticationContinuation = nil
        self.isAuthenticating = false
    }
} 