import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                if searchResults.isEmpty && !searchText.isEmpty {
                    emptyStateView
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(for: newValue)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search your content...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding()
    }
    
    private var searchResultsList: some View {
        List(searchResults) { result in
            NavigationLink(destination: ContentDetailView(content: result.content)) {
                SearchResultCard(result: result)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your search terms.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func performSearch(for queryText: String) {
        guard !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.searchResults = []
            return
        }
        
        // Perform simple text-based search through the content
        let allContent = appState.dataFlowManager.fetchAllContent()
        let query = queryText.lowercased()
        
        self.searchResults = allContent.compactMap { content in
            let contentText = (content.content ?? "").lowercased()
            let summaryText = (content.summary ?? "").lowercased()
            let tagsText = (content.tags ?? "").lowercased()
            
            if contentText.contains(query) || summaryText.contains(query) || tagsText.contains(query) {
                let score = calculateRelevanceScore(content: content, query: query)
                let processedContent = convertToProcessedContent(content: content)
                let matchedTerms = findMatchedTerms(content: content, query: query)
                return SearchResult(content: processedContent, relevanceScore: Float(score), matchedTerms: matchedTerms)
            }
            return nil
        }.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func calculateRelevanceScore(content: ContentEntity, query: String) -> Double {
        var score = 0.0
        let contentText = (content.content ?? "").lowercased()
        let summaryText = (content.summary ?? "").lowercased()
        
        // Higher score for matches in summary
        if summaryText.contains(query) {
            score += 2.0
        }
        
        // Base score for content matches
        if contentText.contains(query) {
            score += 1.0
        }
        
        return score
    }
    
    private func convertToProcessedContent(content: ContentEntity) -> ProcessedContent {
        return ProcessedContent(
            id: content.id ?? UUID(),
            title: content.summary?.isEmpty == false ? content.summary! : "Untitled",
            content: content.content ?? "",
            type: .text, // Default to text type for now
            tags: (content.tags ?? "").split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) },
            summary: content.summary ?? "",
            keyConcepts: [],
            sentiment: .neutral,
            embedding: [],
            createdAt: content.createdAt ?? Date(),
            processedAt: content.processedAt
        )
    }
    
    private func findMatchedTerms(content: ContentEntity, query: String) -> [String] {
        var matchedTerms: [String] = []
        let terms = query.split(separator: " ").map { String($0) }
        
        for term in terms {
            let contentText = (content.content ?? "").lowercased()
            let summaryText = (content.summary ?? "").lowercased()
            
            if contentText.contains(term) || summaryText.contains(term) {
                matchedTerms.append(term)
            }
        }
        
        return matchedTerms
    }
}

struct SearchResultCard: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForContentType(result.content.type))
                    .foregroundColor(.purple)
                Text(result.content.summary)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "Score: %.2f", result.relevanceScore))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(result.content.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
    }
    
    private func iconForContentType(_ type: ContentType) -> String {
        switch type {
        case .text:
            return "doc.text.fill"
        case .image:
            return "photo.fill"
        case .document:
            return "doc.fill"
        default:
            return "doc.fill"
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        // You might need to add some dummy data for the preview to be meaningful
        SearchView()
            .environmentObject(AppState())
    }
}