import Foundation
import NaturalLanguage

@MainActor
class SearchIndexManager: ObservableObject {
    @Published var isInitialized = false
    @Published var indexingProgress: Float = 0.0
    
    // Vector search index (simplified in-memory implementation)
    private var vectorIndex: [UUID: [Float]] = [:]
    private var invertedIndex: [String: Set<UUID>] = [:]
    
    // NLP components
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .language])
    
    // Search configuration
    private let minTokenLength = 2
    private let maxTokensPerContent = 1000
    
    func initialize() async {
        setupNLPComponents()
        await loadExistingIndex()
        isInitialized = true
    }
    
    // MARK: - Index Management
    
    func addToIndex(_ content: ProcessedContent) async throws {
        // Add vector embedding
        vectorIndex[content.id] = content.embedding
        
        // Add to inverted index
        let tokens = extractTokens(from: content)
        for token in tokens {
            if invertedIndex[token] == nil {
                invertedIndex[token] = Set<UUID>()
            }
            invertedIndex[token]?.insert(content.id)
        }
    }
    
    func removeFromIndex(_ contentId: UUID) async throws {
        // Remove from vector index
        vectorIndex.removeValue(forKey: contentId)
        
        // Remove from inverted index
        for (token, ids) in invertedIndex {
            if ids.contains(contentId) {
                invertedIndex[token]?.remove(contentId)
                if invertedIndex[token]?.isEmpty == true {
                    invertedIndex.removeValue(forKey: token)
                }
            }
        }
    }
    
    func rebuildIndex(_ allContent: [ProcessedContent]) async throws {
        indexingProgress = 0.0
        
        // Clear existing indices
        vectorIndex.removeAll()
        invertedIndex.removeAll()
        
        let total = Float(allContent.count)
        
        for (index, content) in allContent.enumerated() {
            try await addToIndex(content)
            indexingProgress = Float(index + 1) / total
        }
        
        await saveIndex()
    }
    
    // MARK: - Search Operations
    
    func search(_ query: SearchQuery) async throws -> [SearchResult] {
        var results: [SearchResult] = []
        
        if query.semanticSearch {
            // Semantic search using vector embeddings
            let embedding = await generateQueryEmbedding(query.text)
            let semanticResults = try await performSemanticSearch(embedding, contentTypes: Set(query.contentTypes))
            results.append(contentsOf: semanticResults)
        }
        
        // Keyword search using inverted index
        let keywordResults = try await performKeywordSearch(query.text, contentTypes: Set(query.contentTypes))
        results.append(contentsOf: keywordResults)
        
        // Combine and deduplicate results
        let combinedResults = try await combineSearchResults(results)
        
        // Apply filters
        let filteredResults = try await applyFilters(combinedResults, query: query)
        
        // Sort by relevance
        return filteredResults.sorted { $0.score > $1.score }
    }
    
    func suggestTags(_ text: String) async throws -> [String] {
        let tokens = extractTokens(from: text)
        // Find related content based on token overlap (placeholder)
        for token in tokens {
            if let relatedIds = invertedIndex[token] {
                for _ in relatedIds {
                    // Placeholder: Fetch and process tags for related content
                }
            }
        }
        
        // Extract meaningful entities and concepts
        let entities = await extractEntities(from: text)
        let concepts = await extractConcepts(from: text)
        
        return (entities + concepts).prefix(10).map { $0 }
    }
    
    func findSimilarContent(_ content: ProcessedContent, limit: Int = 10) async throws -> [SearchResult] {
        let embedding = content.embedding
        return try await performSemanticSearch(embedding, contentTypes: Set(ContentType.allCases), limit: limit)
    }
    
    // MARK: - Private Methods
    
    private func setupNLPComponents() {
        tokenizer.setLanguage(.english)
        // tagger.setLanguage(.english, range: NSRange(location: 0, length: 0)) // Comment out for now
    }
    
    private func loadExistingIndex() async {
        // In a real implementation, this would load from persistent storage
        // For now, we'll start with empty indices
    }
    
    private func saveIndex() async {
        // In a real implementation, this would save to persistent storage
    }
    
    private func extractTokens(from content: ProcessedContent) -> Set<String> {
        var allText = content.originalContent
        if let extractedText = content.extractedText {
            allText += " " + extractedText
        }
        allText += " " + content.summary
        allText += " " + content.tags.joined(separator: " ")
        allText += " " + content.keyConcepts.joined(separator: " ")
        
        return extractTokens(from: allText)
    }
    
    private func extractTokens(from text: String) -> Set<String> {
        var tokens = Set<String>()
        
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange]).lowercased()
            
            // Filter tokens
            if token.count >= minTokenLength &&
               !isStopWord(token) &&
               !token.allSatisfy({ $0.isPunctuation }) {
                tokens.insert(token)
            }
            
            return true
        }
        
        return tokens
    }
    
    private func generateQueryEmbedding(_ query: String) async -> [Float] {
        // In a real implementation, this would use a proper embedding model
        // For now, we'll use a simplified approach similar to the one in MLXManager
        let tokens = extractTokens(from: query)
        var embedding = Array(repeating: Float(0), count: 384)
        
        for token in tokens {
            let hash = token.hashValue
            let embeddingIndex = abs(hash) % embedding.count
            embedding[embeddingIndex] += 1.0 / Float(tokens.count)
        }
        
        // Normalize
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }
        
        return embedding
    }
    
    private func performSemanticSearch(_ queryEmbedding: [Float], contentTypes: Set<ContentType>, limit: Int = 20) async throws -> [SearchResult] {
        var similarities: [(id: UUID, similarity: Float)] = []
        
        for (id, embedding) in vectorIndex {
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            similarities.append((id: id, similarity: similarity))
        }
        
        // Sort by similarity and take top results
        similarities.sort { $0.similarity > $1.similarity }
        let topSimilarities = Array(similarities.prefix(limit))
        
        var results: [SearchResult] = []
        for (_, similarity) in topSimilarities {
            // Placeholder semantic search result
            results.append(SearchResult(
                content: "Semantic search result",
                score: similarity,
                matchedFields: ["semantic"]
            ))
        }
        
        return results
    }
    
    private func performKeywordSearch(_ query: String, contentTypes: Set<ContentType>) async throws -> [SearchResult] {
        let queryTokens = extractTokens(from: query)
        var contentScores: [UUID: Float] = [:]
        
        for token in queryTokens {
            if let matchingIds = invertedIndex[token] {
                for id in matchingIds {
                    contentScores[id, default: 0] += 1.0 / Float(queryTokens.count)
                }
            }
        }
        
        var results: [SearchResult] = []
        for (_, score) in contentScores {
            // Placeholder text search result
            results.append(SearchResult(
                content: "Text search result",
                score: score,
                matchedFields: ["content"],
                highlightedText: query
            ))
        }
        
        return results
    }
    
    private func combineSearchResults(_ results: [SearchResult]) async throws -> [SearchResult] {
        var combinedResults: [UUID: SearchResult] = [:]
        
        for result in results {
            let id = result.id
            if let existing = combinedResults[id] {
                // Combine scores (weighted average)
                let combinedScore = (existing.score + result.score) / 2
                var combinedFields = existing.matchedFields
                combinedFields.append(contentsOf: result.matchedFields)
                
                combinedResults[id] = SearchResult(
                    content: existing.content,
                    score: combinedScore,
                    matchedFields: Array(Set(combinedFields)),
                    highlightedText: existing.highlightedText
                )
            } else {
                combinedResults[id] = result
            }
        }
        
        return Array(combinedResults.values)
    }
    
    private func applyFilters(_ results: [SearchResult], query: SearchQuery) async throws -> [SearchResult] {
        var filteredResults = results
        
        // Filter by content types
        if !query.contentTypes.isEmpty {
            filteredResults = filteredResults.filter { query.contentTypes.contains($0.contentType) }
        }
        
        // Filter by tags
        if !query.tags.isEmpty {
            filteredResults = filteredResults.filter { result in
                let contentTags = Set(result.tags)
                return !Set(query.tags).isDisjoint(with: contentTags)
            }
        }
        
        // Filter by date range
        if let dateRange = query.filters["dateRange"] as? ClosedRange<Date> {
            filteredResults = filteredResults.filter { result in
                dateRange.contains(result.processedAt)
            }
        }
        
        // Filter by sentiment
        if let sentiment = query.filters["sentiment"] as? Sentiment {
            filteredResults = filteredResults.filter { $0.sentiment == sentiment }
        }
        
        return filteredResults
    }
    
    private func extractEntities(from text: String) async -> [String] {
        var entities: [String] = []
        
        tagger.string = text
        let range = NSRange(location: 0, length: text.utf16.count)
        
        let stringRange = Range(range, in: text)!
        tagger.enumerateTags(in: stringRange, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let entity = String(text[tokenRange])
                
                switch tag {
                case .personalName, .placeName, .organizationName:
                    entities.append(entity.lowercased())
                default:
                    break
                }
            }
            return true
        }
        
        return entities
    }
    
    private func extractConcepts(from text: String) async -> [String] {
        // Extract noun phrases and important concepts
        var concepts: [String] = []
        
        tagger.string = text
        let range = NSRange(location: 0, length: text.utf16.count)
        
        let stringRange2 = Range(range, in: text)!
        tagger.enumerateTags(in: stringRange2, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag,
               tag == .noun {
                let concept = String(text[tokenRange]).lowercased()
                if concept.count > 3 && !isStopWord(concept) {
                    concepts.append(concept)
                }
            }
            return true
        }
        
        return concepts
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = Set([
            "the", "be", "to", "of", "and", "a", "in", "that", "have",
            "i", "it", "for", "not", "on", "with", "he", "as", "you",
            "do", "at", "this", "but", "his", "by", "from", "they",
            "we", "say", "her", "she", "or", "an", "will", "my",
            "one", "all", "would", "there", "their"
        ])
        
        return stopWords.contains(word.lowercased())
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
}