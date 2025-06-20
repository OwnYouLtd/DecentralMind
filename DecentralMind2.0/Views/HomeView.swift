import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var recentContent: [ContentEntity] = []
    @State private var isLoading = true
    @State private var stats = ContentStats(count: 0, totalSize: 0)
    
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
                await loadData()
            }
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        await loadRecentContent()
        await loadStats()
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
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Total Items",
                    value: "\(stats.count)",
                    icon: "doc.text",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Size",
                    value: formatBytes(stats.totalSize),
                    icon: "archivebox",
                    color: .green
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
    
    private func loadRecentContent() async {
        isLoading = true
        defer { isLoading = false }
        
        let allContent = appState.dataFlowManager.fetchAllContent()
        self.recentContent = Array(allContent.prefix(10))
    }
    
    private func loadStats() async {
        self.stats = appState.dataFlowManager.getContentStats()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
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
                    .font(.title)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct ContentRowView: View {
    let content: ContentEntity
    
    var body: some View {
        NavigationLink(destination: ContentDetailView(content: content)) {
            HStack(spacing: 16) {
                Image(systemName: iconForContentType(content.contentType))
                    .font(.title)
                    .foregroundColor(.purple)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.summary ?? "No Title")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(content.content ?? "No content")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if let date = content.processedAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        HomeView()
            .environmentObject(AppState(context: context))
    }
}