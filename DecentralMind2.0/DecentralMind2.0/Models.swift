import Foundation
import CoreData // For ContentEntity

struct SearchResult: Identifiable {
    public var id: UUID {
        // Use the entity's UUID. It should always exist for a valid entity.
        return contentEntity.id!
    }
    
    var contentEntity: ContentEntity
    var score: Float
}

struct SearchQuery {
    var text: String
    var limit: Int = 10
}

struct ContentStats {
    var count: Int
    var totalSize: Int64 // size in bytes
} 