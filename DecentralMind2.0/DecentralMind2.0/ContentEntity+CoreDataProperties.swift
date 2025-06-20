//
//  ContentEntity+CoreDataProperties.swift
//  DecentralMind2.0
//
//  Created by Assistant on 20/06/2025.
//
//

import Foundation
import CoreData

extension ContentEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ContentEntity> {
        return NSFetchRequest<ContentEntity>(entityName: "ContentEntity")
    }

    @NSManaged public var category: String?
    @NSManaged public var cid: String?
    @NSManaged public var content: String?
    @NSManaged public var contentType: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var detectedLanguage: String?
    @NSManaged public var embedding: Data?
    @NSManaged public var extractedText: String?
    @NSManaged public var id: UUID?
    @NSManaged public var ipfsHash: String?
    @NSManaged public var isEncrypted: Bool
    @NSManaged public var isLocal: Bool
    @NSManaged public var keyConcepts: String?
    @NSManaged public var ocrConfidence: Float
    @NSManaged public var processedAt: Date?
    @NSManaged public var sentiment: String?
    @NSManaged public var summary: String?
    @NSManaged public var syncStatus: String?
    @NSManaged public var tags: String?
    @NSManaged public var updatedAt: Date?

} 