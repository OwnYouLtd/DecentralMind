import Foundation
import UIKit
import CoreData

// MARK: - Content Types
enum ContentType: String, CaseIterable, Codable {
    case text = "text"
    case note = "note"
    case image = "image"
    case url = "url"
    case document = "document"
    case quote = "quote"
    case highlight = "highlight"
}

// MARK: - Sentiment Analysis
enum Sentiment: String, CaseIterable, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
}

// MARK: - Core Data Structures
struct ProcessedContent: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let type: ContentType
    let tags: [String]
    let summary: String
    let keyConcepts: [String]
    let sentiment: Sentiment
    let embedding: [Float]
    let createdAt: Date
    let processedAt: Date?
    
    init(id: UUID = UUID(), title: String, content: String, type: ContentType, tags: [String] = [], summary: String = "", keyConcepts: [String] = [], sentiment: Sentiment = .neutral, embedding: [Float] = [], createdAt: Date = Date(), processedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.type = type
        self.tags = tags
        self.summary = summary
        self.keyConcepts = keyConcepts
        self.sentiment = sentiment
        self.embedding = embedding
        self.createdAt = createdAt
        self.processedAt = processedAt
    }
}

// MARK: - Search Structures
struct SearchQuery: Identifiable {
    let id: UUID
    let text: String
    let filters: [ContentType]
    let limit: Int
    let createdAt: Date
    
    init(id: UUID = UUID(), text: String, filters: [ContentType] = [], limit: Int = 10, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.filters = filters
        self.limit = limit
        self.createdAt = createdAt
    }
}

struct SearchResult: Identifiable {
    let id: UUID
    let content: ProcessedContent
    let relevanceScore: Float
    let matchedTerms: [String]
    
    init(id: UUID = UUID(), content: ProcessedContent, relevanceScore: Float, matchedTerms: [String]) {
        self.id = id
        self.content = content
        self.relevanceScore = relevanceScore
        self.matchedTerms = matchedTerms
    }
}

// MARK: - OCR Results
struct OCRResult {
    let text: String
    let confidence: Float
    let detectedLanguage: String
    let boundingBoxes: [TextBoundingBox]
    let extractedAt: Date
}

struct TextBoundingBox {
    let text: String
    let frame: CGRect
    let confidence: Float
}

struct StructuredOCRResult {
    let text: String
    let confidence: Float
    let language: String
    let layout: DocumentLayout
    let boundingBoxes: [TextBoundingBox]
    let extractedAt: Date
}

struct DocumentLayout {
    let blocks: [LayoutBlock]
    let readingOrder: [Int]
    let documentType: DocumentType
}

struct LayoutBlock {
    let id: Int
    let text: String
    let frame: CGRect
    let type: BlockType
}

enum BlockType {
    case paragraph
    case heading
    case list
    case table
    case image
}

enum DocumentType {
    case receipt
    case businessCard
    case whiteboard
    case handwritten
    case general
}

// MARK: - Document-Specific Results
enum DocumentOCRResult {
    case receipt(ReceiptData)
    case businessCard(BusinessCardData)
    case whiteboard(WhiteboardData)
    case handwritten(HandwrittenData)
    case general(StructuredOCRResult)
}

struct ReceiptData {
    let merchantName: String
    let items: [ReceiptItem]
    let total: Double
    let date: Date
    let rawText: String
}

struct ReceiptItem {
    let name: String
    let price: Double
    let quantity: Int
}

struct BusinessCardData {
    let name: String
    let company: String
    let title: String
    let email: String
    let phone: String
    let address: String
    let rawText: String
}

struct WhiteboardData {
    let textBlocks: [TextBlock]
    let diagrams: [DiagramElement]
    let equations: [Equation]
    let rawText: String
}

struct TextBlock {
    let text: String
    let frame: CGRect
    let isHandwritten: Bool
}

struct DiagramElement {
    let type: DiagramType
    let frame: CGRect
    let description: String
}

enum DiagramType {
    case arrow
    case box
    case circle
    case line
    case flowchart
    case mindMap
}

struct Equation {
    let latex: String
    let frame: CGRect
    let isHandwritten: Bool
}

struct HandwrittenData {
    let text: String
    let confidence: Float
    let language: String
}

// MARK: - Error Types
enum OCRError: LocalizedError {
    case modelNotLoaded
    case imageProcessingFailed
    case processingFailed(String)
    case invalidInput
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "OCR model is not loaded"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .invalidInput:
            return "Invalid input provided"
        }
    }
}

// MARK: - Storage Errors
enum StorageError: LocalizedError {
    case notFound
    case saveFailed(String)
    case loadFailed(String)
    case encryptionFailed
    case decryptionFailed
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .notFound: return "Item not found"
        case .saveFailed(let reason): return "Save failed: \(reason)"
        case .loadFailed(let reason): return "Load failed: \(reason)"
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed"
        case .invalidFormat: return "Invalid data format"
        }
    }
}

// MARK: - Analysis Results
struct AnalysisMetrics {
    let processedAt: Date
    let processingTime: TimeInterval
    let confidence: Float
    let modelVersion: String
}

struct SemanticAnalysis {
    let entities: [NamedEntity]
    let topics: [String]
    let intentions: [UserIntention]
    let complexity: Float
}

struct NamedEntity {
    let text: String
    let type: EntityType
    let confidence: Float
    let range: NSRange
}

enum EntityType: String, CaseIterable {
    case person = "person"
    case organization = "organization"
    case location = "location"
    case date = "date"
    case product = "product"
    case concept = "concept"
}

struct UserIntention {
    let type: IntentionType
    let confidence: Float
    let context: String
}

enum IntentionType: String, CaseIterable {
    case question = "question"
    case reminder = "reminder"
    case note = "note"
    case research = "research"
    case planning = "planning"
    case reflection = "reflection"
}

// MARK: - Helper Extensions
extension ProcessedContent {
    func toCodableContent() -> CodableProcessedContent {
        return CodableProcessedContent(
            id: id,
            title: title,
            content: content,
            type: type.rawValue,
            tags: tags,
            summary: summary,
            keyConcepts: keyConcepts,
            sentiment: sentiment.rawValue,
            embedding: embedding,
            createdAt: createdAt,
            processedAt: processedAt
        )
    }
    
    static func fromCodableContent(_ codable: CodableProcessedContent) -> ProcessedContent? {
        guard let type = ContentType(rawValue: codable.type),
              let sentiment = Sentiment(rawValue: codable.sentiment) else {
            return nil
        }
        
        return ProcessedContent(
            id: codable.id,
            title: codable.title,
            content: codable.content,
            type: type,
            tags: codable.tags,
            summary: codable.summary,
            keyConcepts: codable.keyConcepts,
            sentiment: sentiment,
            embedding: codable.embedding,
            createdAt: codable.createdAt,
            processedAt: codable.processedAt
        )
    }
}

// MARK: - Codable Wrapper for Encryption
struct CodableProcessedContent: Codable {
    let id: UUID
    let title: String
    let content: String
    let type: String
    let tags: [String]
    let summary: String
    let keyConcepts: [String]
    let sentiment: String
    let embedding: [Float]
    let createdAt: Date
    let processedAt: Date?
} 