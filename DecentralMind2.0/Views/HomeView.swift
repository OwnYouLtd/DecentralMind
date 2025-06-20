import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = true
    @State private var stats = ContentStats(count: 0, totalSize: 0)
    @State private var showingCaptureView = false
    @State private var showingCameraView = false
    @State private var refreshTimer: Timer?
    
    // Observe the published contentEntities instead of using local state
    private var recentContent: [ContentEntity] {
        Array(appState.dataFlowManager.contentEntities.prefix(10))
    }
    
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
        .sheet(isPresented: $showingCaptureView) {
            CaptureView()
                .environmentObject(appState)
        }
        .onAppear {
            Task {
                await loadData()
            }
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private func startRefreshTimer() {
        // Refresh every 2 seconds to catch any processing updates
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                await loadData()
            }
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func loadData() async {
        await loadStats()
        // Force refresh the content entities
        await MainActor.run {
            appState.dataFlowManager.contentEntities = appState.dataFlowManager.fetchAllContent()
        }
        isLoading = false
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
                    showingCaptureView = true
                }
                
                QuickActionCard(
                    title: "Scan Document",
                    icon: "camera.fill",
                    color: .blue
                ) {
                    showingCameraView = true
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
    
    private func loadStats() async {
        self.stats = appState.dataFlowManager.getContentStats()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func convertToProcessedContent(_ content: ContentEntity) -> ProcessedContent {
        return ProcessedContent(
            id: content.id ?? UUID(),
            title: content.summary ?? "Untitled",
            content: content.content ?? "",
            type: ContentType(rawValue: content.contentType ?? "text") ?? .text,
            tags: (content.tags ?? "").components(separatedBy: ",").filter { !$0.isEmpty },
            summary: content.summary ?? "",
            keyConcepts: (content.keyConcepts ?? "").components(separatedBy: ",").filter { !$0.isEmpty },
            sentiment: Sentiment(rawValue: content.sentiment ?? "neutral") ?? .neutral,
            embedding: convertDataToFloatArray(content.embedding),
            createdAt: content.createdAt ?? Date(),
            processedAt: content.processedAt ?? Date()
        )
    }
    
    private func convertDataToFloatArray(_ data: Data?) -> [Float] {
        guard let data = data else { return [] }
        let floatCount = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self).prefix(floatCount))
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
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationLink(destination: ContentDetailView(content: convertToProcessedContent(content))) {
            HStack(spacing: 16) {
                Image(systemName: iconForContentType(content.contentType))
                    .font(.title)
                    .foregroundColor(.purple)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayTitle)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Processing indicator
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    
                    Text(displaySubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Processing status
                    if isProcessing {
                        Text("AI is analyzing...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if let processedAt = content.processedAt {
                        Text("Analyzed \(processedAt, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    if let date = content.createdAt {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Sentiment indicator
                    if let sentiment = content.sentiment, !sentiment.isEmpty && sentiment != "neutral" {
                        Image(systemName: sentimentIcon(sentiment))
                            .font(.caption)
                            .foregroundColor(sentimentColor(sentiment))
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteContent()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func deleteContent() {
        appState.dataFlowManager.deleteContent(content)
    }
    
    private var displayTitle: String {
        if let summary = content.summary, 
           !summary.isEmpty && 
           summary != "No summary available" && 
           summary.count > 20 {
            return summary
        }
        
        if let content = content.content, !content.isEmpty {
            let words = content.components(separatedBy: .whitespacesAndNewlines).prefix(10)
            let joined = words.joined(separator: " ")
            return String(joined.prefix(80)) + (joined.count > 80 ? "..." : "")
        }
        
        return "Untitled Content"
    }
    
    private var displaySubtitle: String {
        if let content = content.content, !content.isEmpty {
            let preview = String(content.prefix(60))
            return preview + (content.count > 60 ? "..." : "")
        }
        return "No content"
    }
    
    private var isProcessing: Bool {
        let hasMeaningfulSummary = content.summary != nil && 
                                  !content.summary!.isEmpty && 
                                  content.summary != "No summary available" &&
                                  content.summary!.count > 20
        return !hasMeaningfulSummary
    }
    
    private func sentimentIcon(_ sentiment: String) -> String {
        switch sentiment.lowercased() {
        case "positive": return "heart.fill"
        case "negative": return "heart.slash.fill"
        default: return "minus.circle.fill"
        }
    }
    
    private func sentimentColor(_ sentiment: String) -> Color {
        switch sentiment.lowercased() {
        case "positive": return .green
        case "negative": return .red
        default: return .gray
        }
    }
    
    private func iconForContentType(_ type: String?) -> String {
        switch type {
        case "text/plain":
            return "doc.text.fill"
        case "note":
            return "note.text"
        case "image/jpeg", "image/png":
            return "photo.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func convertToProcessedContent(_ content: ContentEntity) -> ProcessedContent {
        return ProcessedContent(
            id: content.id ?? UUID(),
            title: displayTitle,
            content: content.content ?? "",
            type: ContentType(rawValue: content.contentType ?? "text") ?? .text,
            tags: (content.tags ?? "").components(separatedBy: ",").filter { !$0.isEmpty },
            summary: content.summary ?? "",
            keyConcepts: (content.keyConcepts ?? "").components(separatedBy: ",").filter { !$0.isEmpty },
            sentiment: Sentiment(rawValue: content.sentiment ?? "neutral") ?? .neutral,
            embedding: convertDataToFloatArray(content.embedding),
            createdAt: content.createdAt ?? Date(),
            processedAt: content.processedAt
        )
    }
    
    private func convertDataToFloatArray(_ data: Data?) -> [Float] {
        guard let data = data else { return [] }
        let floatCount = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self).prefix(floatCount))
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AppState())
    }
}