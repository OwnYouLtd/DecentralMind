import Foundation
import CoreGraphics

// MARK: - OCR Results
struct OCRResult {
    let text: String
    let confidence: Float
    let detectedLanguage: String
    let boundingBoxes: [TextBoundingBox]
    let extractedAt: Date
}

struct StructuredOCRResult {
    let text: String
    let confidence: Float
    let language: String
    let layout: DocumentLayout
    let boundingBoxes: [TextBoundingBox]
    let extractedAt: Date
}

struct TextBoundingBox {
    let text: String
    let rect: CGRect
    let confidence: Float
    let wordLevel: Bool
}

// MARK: - Document Layout
struct DocumentLayout {
    let blocks: [TextBlock]
    let readingOrder: [Int] // Indices of blocks in reading order
    let documentType: DocumentLayoutType
}

enum DocumentLayoutType {
    case general
    case column
    case table
    case form
    case invoice
    case receipt
}

struct TextBlock {
    let id: UUID
    let text: String
    let rect: CGRect
    let type: TextBlockType
    let confidence: Float
    let children: [TextBlock]
}

enum TextBlockType {
    case paragraph
    case heading
    case listItem
    case table
    case equation
    case diagram
    case signature
}

// MARK: - Document Types
enum DocumentType {
    case general
    case receipt
    case businessCard
    case whiteboard
    case handwritten
}

enum DocumentOCRResult {
    case general(StructuredOCRResult)
    case receipt(ReceiptData)
    case businessCard(BusinessCardData)
    case whiteboard(WhiteboardData)
    case handwritten(HandwrittenData)
}

// MARK: - Specialized Data Types
struct ReceiptData {
    let merchantName: String
    let items: [ReceiptItem]
    let total: Double
    let tax: Double?
    let date: Date
    let paymentMethod: String?
    let rawText: String
}

struct ReceiptItem {
    let name: String
    let quantity: Int?
    let price: Double
    let category: String?
}

struct BusinessCardData {
    let name: String
    let company: String
    let title: String
    let email: String
    let phone: String
    let address: String
    let website: String?
    let socialMedia: [String: String]
    let rawText: String
}

struct WhiteboardData {
    let textBlocks: [TextBlock]
    let diagrams: [DiagramElement]
    let equations: [MathEquation]
    let sketches: [SketchElement]
    let rawText: String
}

struct DiagramElement {
    let id: UUID
    let type: DiagramType
    let boundingBox: CGRect
    let elements: [DiagramComponent]
}

enum DiagramType {
    case flowchart
    case mindMap
    case organizationChart
    case timeline
    case graph
    case unknown
}

struct DiagramComponent {
    let text: String?
    let shape: ShapeType
    let boundingBox: CGRect
    let connections: [UUID] // IDs of connected components
}

enum ShapeType {
    case rectangle
    case circle
    case diamond
    case arrow
    case line
    case text
}

struct MathEquation {
    let id: UUID
    let latex: String
    let boundingBox: CGRect
    let confidence: Float
}

struct SketchElement {
    let id: UUID
    let type: SketchType
    let boundingBox: CGRect
    let strokes: [StrokeData]
}

enum SketchType {
    case drawing
    case annotation
    case highlight
    case underline
}

struct StrokeData {
    let points: [CGPoint]
    let pressure: [Float]?
    let timestamp: [TimeInterval]
}

struct HandwrittenData {
    let text: String
    let confidence: Float
    let language: String
    let writingStyle: WritingStyle
    let corrections: [TextCorrection]
}

enum WritingStyle {
    case print
    case cursive
    case mixed
}

struct TextCorrection {
    let original: String
    let corrected: String
    let confidence: Float
    let range: NSRange
}

// MARK: - OCR Errors
enum OCRError: LocalizedError {
    case modelNotLoaded
    case imageProcessingFailed
    case unsupportedImageFormat
    case ocrProcessingFailed
    case insufficientMemory
    case textNotFound
    case languageNotSupported
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "OCR model not loaded"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .unsupportedImageFormat:
            return "Unsupported image format"
        case .ocrProcessingFailed:
            return "OCR processing failed"
        case .insufficientMemory:
            return "Insufficient memory for OCR processing"
        case .textNotFound:
            return "No text found in image"
        case .languageNotSupported:
            return "Language not supported"
        }
    }
}

// MARK: - OCR Configuration
struct OCRConfiguration {
    let supportedLanguages: [String]
    let maxImageSize: CGSize
    let confidenceThreshold: Float
    let enableStructuralAnalysis: Bool
    let enableHandwritingRecognition: Bool
    let batchProcessingEnabled: Bool
    let maxBatchSize: Int
    
    static let `default` = OCRConfiguration(
        supportedLanguages: ["en", "es", "fr", "de", "it", "pt", "zh", "ja", "ko"],
        maxImageSize: CGSize(width: 4096, height: 4096),
        confidenceThreshold: 0.7,
        enableStructuralAnalysis: true,
        enableHandwritingRecognition: true,
        batchProcessingEnabled: true,
        maxBatchSize: 10
    )
}