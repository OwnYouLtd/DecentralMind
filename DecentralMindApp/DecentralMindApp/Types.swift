import Foundation
import SwiftUI

// MARK: - Content Types
enum ContentType: String, CaseIterable, Codable {
    case text = "text"
    case image = "image"
    case url = "url"
    case document = "document"
    case note = "note"
    case quote = "quote"
    case highlight = "highlight"
}

enum Sentiment: String, CaseIterable, Codable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
}

// MARK: - Shared Types
struct ImageMetadata: Codable {
    let width: Int
    let height: Int
    let format: String
    let colorSpace: String?
    let hasAlpha: Bool
    let dpi: Float?
    
    func toDictionary() -> [String: Any] {
        return [
            "width": width,
            "height": height,
            "format": format,
            "colorSpace": colorSpace ?? NSNull(),
            "hasAlpha": hasAlpha,
            "dpi": dpi ?? NSNull()
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> ImageMetadata? {
        guard let width = dict["width"] as? Int,
              let height = dict["height"] as? Int,
              let format = dict["format"] as? String,
              let hasAlpha = dict["hasAlpha"] as? Bool else {
            return nil
        }
        
        let colorSpace = dict["colorSpace"] as? String
        let dpi = dict["dpi"] as? Float
        
        return ImageMetadata(
            width: width,
            height: height,
            format: format,
            colorSpace: colorSpace,
            hasAlpha: hasAlpha,
            dpi: dpi
        )
    }
}

// MARK: - Statistics Types

// Missing types for compilation

struct ProcessedContent: Identifiable, Codable {
    let id: UUID
    let content: String
    let originalContent: String
    let contentType: ContentType
    let category: String
    let tags: [String]
    let summary: String
    let keyConcepts: [String]
    let sentiment: Sentiment
    let processedAt: Date
    let embedding: [Float] // Vector embedding for semantic search
    var ipfsHash: String? // IPFS content hash
    var isEncrypted: Bool = true
    
    // OCR-specific fields
    var extractedText: String?
    var ocrConfidence: Float?
    var detectedLanguage: String?
    
    // Metadata
    var sourceURL: String?
    var fileSize: Int64?
    var imageMetadata: ImageMetadata?
    
    init(id: UUID = UUID(), content: String, originalContent: String? = nil, summary: String = "", contentType: ContentType = .text, category: String = "", tags: [String] = [], keyConcepts: [String] = [], sentiment: Sentiment = .neutral, embedding: [Float] = [], ipfsHash: String? = nil, isEncrypted: Bool = false, extractedText: String? = nil, ocrConfidence: Float? = nil, detectedLanguage: String? = nil, sourceURL: String? = nil, fileSize: Int64? = nil, imageMetadata: ImageMetadata? = nil) {
        self.id = id
        self.content = content
        self.originalContent = originalContent ?? content
        self.summary = summary
        self.contentType = contentType
        self.processedAt = Date()
        self.category = category
        self.tags = tags
        self.keyConcepts = keyConcepts
        self.sentiment = sentiment
        self.embedding = embedding
        self.ipfsHash = ipfsHash
        self.isEncrypted = isEncrypted
        self.extractedText = extractedText
        self.ocrConfidence = ocrConfidence
        self.detectedLanguage = detectedLanguage
        self.sourceURL = sourceURL
        self.fileSize = fileSize
        self.imageMetadata = imageMetadata
    }
}

struct SearchQuery {
    let text: String
    let filters: [String: Any]
    let semanticSearch: Bool
    let contentTypes: [ContentType]
    let tags: [String]
    
    init(text: String, filters: [String: Any] = [:], semanticSearch: Bool = false, contentTypes: [ContentType] = ContentType.allCases, tags: [String] = []) {
        self.text = text
        self.filters = filters
        self.semanticSearch = semanticSearch
        self.contentTypes = contentTypes
        self.tags = tags
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let content: String
    let score: Float
    let matchedFields: [String]
    let highlightedText: String
    let contentType: ContentType
    let tags: [String]
    let processedAt: Date
    let sentiment: Sentiment
    
    init(content: String, score: Float = 1.0, matchedFields: [String] = [], highlightedText: String? = nil, contentType: ContentType = .text, tags: [String] = [], processedAt: Date = Date(), sentiment: Sentiment = .neutral) {
        self.content = content
        self.score = score
        self.matchedFields = matchedFields
        self.highlightedText = highlightedText ?? content
        self.contentType = contentType
        self.tags = tags
        self.processedAt = processedAt
        self.sentiment = sentiment
    }
}

struct SimilaritySearchQuery {
    let embedding: [Float]
    let threshold: Float
    let limit: Int
    
    init(embedding: [Float], threshold: Float = 0.8, limit: Int = 10) {
        self.embedding = embedding
        self.threshold = threshold
        self.limit = limit
    }
}

struct EmbeddingSearchQuery {
    let text: String
    let threshold: Float
    let limit: Int
    
    init(text: String, threshold: Float = 0.8, limit: Int = 10) {
        self.text = text
        self.threshold = threshold
        self.limit = limit
    }
}

struct BooleanSearchQuery {
    let query: String
    let fields: [String]
    
    init(query: String, fields: [String] = []) {
        self.query = query
        self.fields = fields
    }
}

struct IndexEntry {
    let id = UUID()
    let content: String
    let embedding: [Float]
    let metadata: [String: Any]
    
    init(content: String, embedding: [Float], metadata: [String: Any] = [:]) {
        self.content = content
        self.embedding = embedding
        self.metadata = metadata
    }
}

// Raw Content Type
struct RawContent {
    let content: String
    let type: ContentType
    let imageData: Data?
    let metadata: [String: Any]
    
    init(content: String, type: ContentType, imageData: Data? = nil, metadata: [String: Any] = [:]) {
        self.content = content
        self.type = type
        self.imageData = imageData
        self.metadata = metadata
    }
}

// Missing View Types
struct ContentListView: View {
    var body: some View {
        Text("Content List")
            .foregroundColor(.secondary)
    }
}

struct ContentDetailView: View {
    let content: ProcessedContent
    
    var body: some View {
        VStack {
            Text("Content Detail")
                .font(.title)
            Text(content.summary.isEmpty ? content.content : content.summary)
                .padding()
        }
    }
}

struct DocumentScannerView: View {
    let onImagesScanned: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Document Scanner")
                .font(.title)
            
            Text("Camera-based document scanning would be implemented here")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Close") {
                dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

struct CameraView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Camera")
                .font(.title)
            
            Text("Camera interface would be implemented here")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Close") {
                dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}