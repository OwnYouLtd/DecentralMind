import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var selectedContentTypes: Set<ContentType> = Set(ContentType.allCases)
    @State private var selectedTags: Set<String> = []
    @State private var semanticSearch = true
    @State private var showingFilters = false
    @State private var recentSearches: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Search Results
                if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                    emptyStateView
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: 
                Button("Filters") {
                    showingFilters = true
                }
            )
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView(
                    selectedContentTypes: $selectedContentTypes,
                    selectedTags: $selectedTags,
                    semanticSearch: $semanticSearch
                )
            }
        }
        .onAppear {
            loadRecentSearches()
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                performSearch()
            } else {
                searchResults.removeAll()
            }
        }
    }
    
    private var searchBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search your content...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performSearch()
                        addToRecentSearches(searchText)
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        searchResults.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Search Mode Toggle
            if !searchText.isEmpty {
                HStack {
                    Button(action: { semanticSearch = false }) {
                        Text("Keyword")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(semanticSearch ? Color.clear : Color.purple)
                            .foregroundColor(semanticSearch ? .purple : .white)
                            .cornerRadius(16)
                    }
                    
                    Button(action: { semanticSearch = true }) {
                        Text("Semantic")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(semanticSearch ? Color.purple : Color.clear)
                            .foregroundColor(semanticSearch ? .white : .purple)
                            .cornerRadius(16)
                    }
                    
                    Spacer()
                    
                    Text("\(searchResults.count) results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if searchText.isEmpty {
                    // Recent searches and suggestions
                    recentSearchesSection
                } else if isSearching {
                    // Loading state
                    ProgressView()
                        .frame(height: 100)
                } else {
                    // Search results
                    ForEach(searchResults) { result in
                        SearchResultCard(result: result)
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your search terms or filters")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Clear Filters") {
                selectedContentTypes = Set(ContentType.allCases)
                selectedTags.removeAll()
                performSearch()
            }
            .foregroundColor(.purple)
        }
        .padding()
    }
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Searches")
                        .font(.headline)
                    
                    ForEach(recentSearches, id: \.self) { search in
                        Button(action: {
                            searchText = search
                            performSearch()
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text(search)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Quick search suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Searches")
                    .font(.headline)
                
                let suggestions = ["notes from this week", "important documents", "images", "quotes"]
                
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        searchText = suggestion
                        performSearch()
                    }) {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.purple)
                            Text(suggestion)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Search Functions
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSearching = true
        
        Task {
            do {
                let query = SearchQuery(
                    text: searchText,
                    semanticSearch: semanticSearch,
                    contentTypes: Array(selectedContentTypes),
                    tags: Array(selectedTags)
                )
                
                let results = try await appState.searchIndexManager.search(query)
                
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    print("Search failed: \(error)")
                }
            }
        }
    }
    
    private func addToRecentSearches(_ search: String) {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        recentSearches = Array(recentSearches.prefix(5))
        saveRecentSearches()
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }
}

struct SearchResultCard: View {
    let result: SearchResult
    
    var body: some View {
        NavigationLink {
            ContentDetailView(content: convertSearchResultToProcessedContent(result))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Content type indicator
                    Image(systemName: contentTypeIcon)
                        .foregroundColor(contentTypeColor)
                    
                    Text(result.contentType.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Relevance score
                    Text(String(format: "%.1f", result.score))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Content preview
                Text(result.content)
                    .font(.subheadline)
                    .lineLimit(3)
                    .foregroundColor(.primary)
                
                // Highlighted text
                Text(result.highlightedText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                
                // Tags
                if !result.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(result.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                // Metadata
                HStack {
                    Text(result.processedAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Matched: \(result.matchedFields.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var contentTypeIcon: String {
        switch result.contentType {
        case .text, .note:
            return "doc.text"
        case .image:
            return "photo"
        case .url:
            return "link"
        case .document:
            return "doc"
        case .quote:
            return "quote.bubble"
        case .highlight:
            return "highlighter"
        }
    }
    
    private var contentTypeColor: Color {
        switch result.contentType {
        case .text, .note:
            return .blue
        case .image:
            return .green
        case .url:
            return .orange
        case .document:
            return .red
        case .quote:
            return .purple
        case .highlight:
            return .yellow
        }
    }
    
    private func convertSearchResultToProcessedContent(_ result: SearchResult) -> ProcessedContent {
        return ProcessedContent(
            content: result.content,
            contentType: result.contentType,
            tags: result.tags,
            sentiment: result.sentiment
        )
    }
}

struct SearchFiltersView: View {
    @Binding var selectedContentTypes: Set<ContentType>
    @Binding var selectedTags: Set<String>
    @Binding var semanticSearch: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Search Mode") {
                    Toggle("Semantic Search", isOn: $semanticSearch)
                }
                
                Section("Content Types") {
                    ForEach(ContentType.allCases, id: \.self) { type in
                        Toggle(type.rawValue.capitalized, isOn: Binding(
                            get: { selectedContentTypes.contains(type) },
                            set: { isSelected in
                                if isSelected {
                                    selectedContentTypes.insert(type)
                                } else {
                                    selectedContentTypes.remove(type)
                                }
                            }
                        ))
                    }
                }
                
                Section("Actions") {
                    Button("Clear All Filters") {
                        selectedContentTypes = Set(ContentType.allCases)
                        selectedTags.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState())
}