import Foundation

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

// MARK: - Sentiment
enum Sentiment: String, CaseIterable, Codable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
}

// A simplified placeholder struct for now.
// We can reintroduce the full struct from your backup later.
struct ProcessedContent {
    let id: UUID
    let content: String
}