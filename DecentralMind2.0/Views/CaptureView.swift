import SwiftUI
import PhotosUI
import VisionKit

struct CaptureView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingImagePicker = false
    @State private var showingDocumentScanner = false
    @State private var showingCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var textInput = ""
    @State private var urlInput = ""
    @State private var selectedContentType: ContentType = .text
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Content Type Picker
                    contentTypePicker
                    
                    // Input Section
                    inputSection
                    
                    // Action Buttons
                    actionButtons
                    
                    // Processing Status
                    if isProcessing {
                        processingView
                    }
                }
                .padding()
            }
            .navigationTitle("Capture")
            .alert("Processing Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedItem, matching: .images)
        .fullScreenCover(isPresented: $showingDocumentScanner) {
            DocumentScannerView { images in
                Task {
                    await processScannedImages(images)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                Task {
                    await processImage(image)
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                await processSelectedPhoto(newItem)
            }
        }
    }
    
    private var contentTypePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content Type")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ContentType.allCases, id: \.self) { type in
                        ContentTypeCard(
                            type: type,
                            isSelected: selectedContentType == type
                        ) {
                            selectedContentType = type
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            switch selectedContentType {
            case .text, .note, .quote, .highlight:
                textInputSection
            case .url:
                urlInputSection
            case .image, .document:
                imageInputSection
            }
        }
    }
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(textInputTitle)
                .font(.headline)
            
            TextEditor(text: $textInput)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                )
            
            if textInput.isEmpty {
                Text(textInputPlaceholder)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Website URL")
                .font(.headline)
            
            TextField("https://example.com", text: $urlInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
    
    private var imageInputSection: some View {
        VStack(spacing: 16) {
            Text("Choose Image Source")
                .font(.headline)
            
            VStack(spacing: 12) {
                CaptureButton(
                    title: "Take Photo",
                    icon: "camera.fill",
                    color: .blue
                ) {
                    showingCamera = true
                }
                
                CaptureButton(
                    title: "Scan Document",
                    icon: "doc.text.viewfinder",
                    color: .green
                ) {
                    showingDocumentScanner = true
                }
                
                CaptureButton(
                    title: "Choose from Photos",
                    icon: "photo.on.rectangle",
                    color: .orange
                ) {
                    showingImagePicker = true
                }
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: processContent) {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("Process with AI")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProcess ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canProcess || isProcessing)
            
            if !textInput.isEmpty || !urlInput.isEmpty {
                Button("Clear") {
                    clearInputs()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Processing with AI...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("This may take a few seconds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private var textInputTitle: String {
        switch selectedContentType {
        case .text:
            return "Text Content"
        case .note:
            return "Note"
        case .quote:
            return "Quote"
        case .highlight:
            return "Highlight"
        default:
            return "Content"
        }
    }
    
    private var textInputPlaceholder: String {
        switch selectedContentType {
        case .text:
            return "Enter any text content you'd like to analyze..."
        case .note:
            return "Write your note here..."
        case .quote:
            return "Enter a quote you'd like to save..."
        case .highlight:
            return "Paste highlighted text here..."
        default:
            return "Enter content..."
        }
    }
    
    private var canProcess: Bool {
        switch selectedContentType {
        case .text, .note, .quote, .highlight:
            return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .url:
            return !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image, .document:
            return false // These are processed immediately when selected
        }
    }
    
    // MARK: - Actions
    
    private func processContent() {
        Task {
            await processUserInput()
        }
    }
    
    private func processUserInput() async {
        let mlxManager = appState.mlxManager
        let localStorageManager = appState.localStorageManager
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let rawContent: RawContent
            
            switch selectedContentType {
            case .text, .note, .quote, .highlight:
                rawContent = RawContent(
                    content: textInput,
                    type: selectedContentType
                )
            case .url:
                rawContent = RawContent(
                    content: urlInput,
                    type: .url
                )
            case .image, .document:
                return // These are handled separately
            }
            
            // Process content with MLX directly
            let analysisResult = try await mlxManager.processContent(rawContent.content, type: rawContent.type)
            
            // Create ProcessedContent
            let processedContent = ProcessedContent(
                content: rawContent.content,
                originalContent: rawContent.content,
                summary: analysisResult.summary,
                contentType: rawContent.type,
                category: analysisResult.category,
                tags: analysisResult.tags,
                keyConcepts: analysisResult.keyConcepts,
                sentiment: analysisResult.sentiment,
                embedding: analysisResult.embedding
            )
            
            // Save to local storage
            try await localStorageManager.save(processedContent)
            
            // Clear inputs after successful processing
            clearInputs()
            
            // Show success feedback
            showSuccess()
            
        } catch {
            showError("Failed to process content: \(error.localizedDescription)")
        }
    }
    
    private func processSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                showError("Failed to load image")
                return
            }
            
            await processImage(image, data: data)
            
        } catch {
            showError("Failed to process image: \(error.localizedDescription)")
        }
    }
    
    private func processImage(_ image: UIImage, data: Data? = nil) async {
        let mlxManager = appState.mlxManager
        let localStorageManager = appState.localStorageManager
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let imageData = data ?? image.jpegData(compressionQuality: 0.8) ?? Data()
            
            // Process image with MLX directly
            let analysisResult = try await mlxManager.processContent("Image content", type: ContentType.image)
            
            // Create ProcessedContent
            let processedContent = ProcessedContent(
                content: "Image content",
                originalContent: "Image content",
                summary: analysisResult.summary,
                contentType: ContentType.image,
                category: analysisResult.category,
                tags: analysisResult.tags,
                keyConcepts: analysisResult.keyConcepts,
                sentiment: analysisResult.sentiment,
                embedding: analysisResult.embedding,
                fileSize: Int64(imageData.count)
            )
            
            // Save to local storage
            try await localStorageManager.save(processedContent)
            
            showSuccess()
            
        } catch {
            showError("Failed to process image: \(error.localizedDescription)")
        }
    }
    
    private func processScannedImages(_ images: [UIImage]) async {
        for image in images {
            await processImage(image)
        }
    }
    
    private func clearInputs() {
        textInput = ""
        urlInput = ""
        selectedItem = nil
    }
    
    private func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
    
    private func showSuccess() {
        // In a real app, you might want to show a success toast or navigate away
        alertMessage = "Content processed successfully!"
        showingAlert = true
    }
}

struct ContentTypeCard: View {
    let type: ContentType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .purple)
                
                Text(displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? Color.purple : Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch type {
        case .text:
            return "doc.text"
        case .note:
            return "note.text"
        case .quote:
            return "quote.bubble"
        case .highlight:
            return "highlighter"
        case .url:
            return "link"
        case .image:
            return "photo"
        case .document:
            return "doc"
        }
    }
    
    private var displayName: String {
        switch type {
        case .text:
            return "Text"
        case .note:
            return "Note"
        case .quote:
            return "Quote"
        case .highlight:
            return "Highlight"
        case .url:
            return "Website"
        case .image:
            return "Image"
        case .document:
            return "Document"
        }
    }
}

struct CaptureButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .padding()
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CaptureView()
        .environmentObject(AppState())
}