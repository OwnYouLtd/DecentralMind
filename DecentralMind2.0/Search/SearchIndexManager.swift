import Foundation
import NaturalLanguage
import CoreData

@MainActor
class SearchIndexManager: ObservableObject {
    private var invertedIndex: [String: Set<UUID>] = [:]
    private var contentCache: [UUID: ContentEntity] = [:]
    private let tokenizer = NLTokenizer(unit: .word)
    
    private let dataFlowManager: DataFlowManager

    init(dataFlowManager: DataFlowManager) {
        self.dataFlowManager = dataFlowManager
        self.tokenizer.setLanguage(.english)
        Task {
            await rebuildIndex()
        }
    }

    func rebuildIndex() async {
        print("Starting index rebuild...")
        let allContent = dataFlowManager.fetchAllContent()
        
        // Clear existing index and cache
        invertedIndex.removeAll()
        contentCache.removeAll()
        
        for content in allContent {
            guard let id = content.id else { continue }
            contentCache[id] = content
            let tokens = extractTokens(from: content)
            for token in tokens {
                invertedIndex[token, default: Set<UUID>()].insert(id)
            }
        }
        print("Index rebuild complete. Indexed \(allContent.count) items.")
    }

    func search(_ query: SearchQuery) -> [SearchResult] {
        let queryTokens = extractTokens(from: query.text)
        var contentScores: [UUID: Float] = [:]

        for token in queryTokens {
            if let matchingIds = invertedIndex[token] {
                for id in matchingIds {
                    contentScores[id, default: 0.0] += 1.0
                }
            }
        }

        let results = contentScores.compactMap { (id, score) -> SearchResult? in
            guard let contentEntity = contentCache[id] else { return nil }
            
            // Convert ContentEntity to ProcessedContent
            let processedContent = ProcessedContent(
                id: contentEntity.id ?? UUID(),
                title: contentEntity.summary ?? "Untitled",
                content: contentEntity.content ?? "",
                type: ContentType(rawValue: contentEntity.contentType ?? "text") ?? .text,
                tags: (contentEntity.tags ?? "").components(separatedBy: ",").filter { !$0.isEmpty },
                summary: contentEntity.summary ?? "",
                keyConcepts: (contentEntity.keyConcepts ?? "").components(separatedBy: ",").filter { !$0.isEmpty },
                sentiment: Sentiment(rawValue: contentEntity.sentiment ?? "neutral") ?? .neutral,
                embedding: convertDataToFloatArray(contentEntity.embedding),
                createdAt: contentEntity.createdAt ?? Date(),
                processedAt: contentEntity.processedAt ?? Date()
            )
            
            return SearchResult(
                content: processedContent,
                relevanceScore: score,
                matchedTerms: queryTokens.filter { token in
                    extractTokens(from: contentEntity).contains(token)
                }
            )
        }

        // Sort by score and return the top results as defined by the query limit
        return Array(results.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(query.limit))
    }

    private func extractTokens(from content: ContentEntity) -> Set<String> {
        var textCorpus = ""
        textCorpus += content.content ?? ""
        textCorpus += " " + (content.extractedText ?? "")
        textCorpus += " " + (content.summary ?? "")
        textCorpus += " " + (content.tags ?? "")
        textCorpus += " " + (content.keyConcepts ?? "")
        
        return extractTokens(from: textCorpus)
    }

    private func extractTokens(from text: String) -> Set<String> {
        var tokens = Set<String>()
        tokenizer.string = text.lowercased()
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
            if token.count > 2 && !isStopWord(token) {
                tokens.insert(token)
            }
            return true
        }
        return tokens
    }

    private func isStopWord(_ token: String) -> Bool {
        // A basic list of English stop words. This could be expanded.
        let stopWords: Set<String> = ["a", "about", "above", "after", "again", "against", "all", "am", "an", "and", "any", "are", "aren't", "as", "at", "be", "because", "been", "before", "being", "below", "between", "both", "but", "by", "can't", "cannot", "could", "couldn't", "did", "didn't", "do", "does", "doesn't", "doing", "don't", "down", "during", "each", "few", "for", "from", "further", "had", "hadn't", "has", "hasn't", "have", "haven't", "having", "he", "he'd", "he'll", "he's", "her", "here", "here's", "hers", "herself", "him", "himself", "his", "how", "how's", "i", "i'd", "i'll", "i'm", "i've", "if", "in", "into", "is", "isn't", "it", "it's", "its", "itself", "let's", "me", "more", "most", "mustn't", "my", "myself", "no", "nor", "not", "of", "off", "on", "once", "only", "or", "other", "ought", "our", "ours", "ourselves", "out", "over", "own", "same", "shan't", "she", "she'd", "she'll", "she's", "should", "shouldn't", "so", "some", "such", "than", "that", "that's", "the", "their", "theirs", "them", "themselves", "then", "there", "there's", "these", "they", "they'd", "they'll", "they're", "they've", "this", "those", "through", "to", "too", "under", "until", "up", "very", "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were", "weren't", "what", "what's", "when", "when's", "where", "where's", "which", "while", "who", "who's", "whom", "why", "why's", "with", "won't", "would", "wouldn't", "you", "you'd", "you'll", "you're", "you've", "your", "yours", "yourself", "yourselves"]
        return stopWords.contains(token)
    }

    private func convertDataToFloatArray(_ data: Data?) -> [Float] {
        guard let data = data else { return [] }
        let floatCount = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self).prefix(floatCount))
        }
    }
}