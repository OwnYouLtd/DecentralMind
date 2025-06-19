import Foundation
import CoreData

@objc(ContentEntity)
public class ContentEntity: NSManagedObject {
    @NSManaged public var category: String?
    @NSManaged public var contentType: String?
    @NSManaged public var detectedLanguage: String?
    @NSManaged public var embedding: Data?
    @NSManaged public var extractedText: String?
    @NSManaged public var id: UUID?
    @NSManaged public var ipfsHash: String?
    @NSManaged public var isEncrypted: Bool
    @NSManaged public var keyConcepts: String?
    @NSManaged public var ocrConfidence: Float
    @NSManaged public var originalContent: String?
    @NSManaged public var processedAt: Date?
    @NSManaged public var sentiment: String?
    @NSManaged public var summary: String?
    @NSManaged public var tags: String?
}

extension ContentEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ContentEntity> {
        return NSFetchRequest<ContentEntity>(entityName: "ContentEntity")
    }
}

// MARK: - Core Data Entity Extension
extension ContentEntity {
    func toProcessedContent() -> ProcessedContent? {
        guard let id = self.id,
              let originalContent = self.originalContent,
              let contentTypeString = self.contentType,
              let contentType = ContentType(rawValue: contentTypeString),
              let category = self.category,
              let summary = self.summary,
              let sentimentString = self.sentiment,
              let sentiment = Sentiment(rawValue: sentimentString),
              let processedAt = self.processedAt,
              let embeddingData = self.embedding,
              let embedding = try? JSONDecoder().decode([Float].self, from: embeddingData) else {
            return nil
        }
        
        let tags = self.tags?.components(separatedBy: ",") ?? []
        let keyConcepts = self.keyConcepts?.components(separatedBy: ",") ?? []
        
        return ProcessedContent(
            id: id,
            content: originalContent,
            originalContent: originalContent,
            summary: summary,
            contentType: contentType,
            category: category,
            tags: tags,
            keyConcepts: keyConcepts,
            sentiment: sentiment,
            embedding: embedding,
            ipfsHash: self.ipfsHash,
            isEncrypted: self.isEncrypted,
            extractedText: self.extractedText,
            ocrConfidence: self.ocrConfidence > 0 ? self.ocrConfidence : nil,
            detectedLanguage: self.detectedLanguage
        )
    }
}