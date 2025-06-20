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
        .onChange(of: searchText) { newValue in
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
            NavigationLink(destination: ContentDetailView(content: result.contentEntity)) {
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
        
        let query = SearchQuery(text: queryText)
        self.searchResults = appState.searchIndexManager.search(query)
    }
}

struct SearchResultCard: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForContentType(result.contentEntity.contentType))
                    .foregroundColor(.purple)
                Text(result.contentEntity.summary ?? "No Title")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "Score: %.2f", result.score))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(result.contentEntity.originalContent ?? "No content...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
    }
    
    private func iconForContentType(_ type: String?) -> String {
        switch type {
        case "text/plain":
            return "doc.text.fill"
        case "image/jpeg", "image/png":
            return "photo.fill"
        default:
            return "doc.fill"
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        // You might need to add some dummy data for the preview to be meaningful
        SearchView()
            .environmentObject(AppState(context: context))
    }
}