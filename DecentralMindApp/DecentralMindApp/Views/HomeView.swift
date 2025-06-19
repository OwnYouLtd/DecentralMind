import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var recentContent: [ProcessedContent] = []
    @State private var isLoading = true
    @State private var stats = ContentStats(totalItems: 0, categories: [], lastUpdated: Date())
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Stats
                    statsSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Content
                    recentContentSection
                }
                .padding()
            }
            .navigationTitle("DecentralMind")
            .refreshable {
                await loadRecentContent()
            }
        }
        .onAppear {
            Task {
                await loadRecentContent()
                await loadStats()
            }
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Overview")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Total Items",
                    value: "\(stats.totalItems)",
                    icon: "doc.text",
                    color: .blue
                )
                
                StatCard(
                    title: "Categories",
                    value: "\(stats.categories.count)",
                    icon: "folder",
                    color: .green
                )
                
                StatCard(
                    title: "This Week",
                    value: "\(recentThisWeek)",
                    icon: "calendar",
                    color: .orange
                )
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                QuickActionCard(
                    title: "Add Note",
                    icon: "plus.circle.fill",
                    color: .purple
                ) {
                    // Navigate to capture view
                }
                
                QuickActionCard(
                    title: "Scan Document",
                    icon: "camera.fill",
                    color: .blue
                ) {
                    // Open camera for document scanning
                }
                
                QuickActionCard(
                    title: "Search All",
                    icon: "magnifyingglass",
                    color: .green
                ) {
                    // Navigate to search
                }
                
                QuickActionCard(
                    title: "Sync Now",
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange
                ) {
                    Task {
                        try? await appState.ipfsManager.syncAll()
                    }
                }
            }
        }
    }
    
    private var recentContentSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Content")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    ContentListView()
                }
                .font(.caption)
                .foregroundColor(.purple)
            }
            
            if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if recentContent.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No content yet")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Start by adding your first note or scanning a document")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recentContent.prefix(5)) { content in
                        ContentRowView(content: content)
                    }
                }
            }
        }
    }
    
    private var recentThisWeek: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return recentContent.filter { $0.processedAt >= oneWeekAgo }.count
    }
    
    private func loadRecentContent() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            recentContent = try await appState.localStorageManager.fetchAll(limit: 10)
        } catch {
            print("Failed to load recent content: \(error)")
        }
    }
    
    private func loadStats() async {
        do {
            stats = try await appState.localStorageManager.getContentStats()
        } catch {
            print("Failed to load stats: \(error)")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContentRowView: View {
    let content: ProcessedContent
    
    var body: some View {
        NavigationLink {
            ContentDetailView(content: content)
        } label: {
            HStack(spacing: 12) {
                // Content type icon
                Image(systemName: contentTypeIcon)
                    .font(.title3)
                    .foregroundColor(contentTypeColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.summary.isEmpty ? content.originalContent : content.summary)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(content.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(content.processedAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var contentTypeIcon: String {
        switch content.contentType {
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
        switch content.contentType {
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
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}