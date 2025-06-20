import SwiftUI

struct ContentDetailView: View {
    let content: ProcessedContent
    @State private var showingOriginalContent = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Processing Status Indicator
                if content.summary.isEmpty || content.summary == "No summary available" {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing content...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // AI Summary - TOP PRIORITY DISPLAY
                if !content.summary.isEmpty && content.summary != "No summary available" {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                            Text("AI Summary")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Text(content.summary)
                            .font(.body)
                            .lineLimit(nil) // Show full summary, no truncation
                            .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading) // Take full width
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.05)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }
                }
                
                // Original Content Button (Click to View)
                if !content.content.isEmpty {
                    Button(action: {
                        showingOriginalContent = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.gray)
                            Text("View Original Content")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                
                // Key Concepts
                if !content.keyConcepts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                            Text("Key Concepts")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                            ForEach(content.keyConcepts, id: \.self) { concept in
                                Text(concept)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                
                // Tags
                if !content.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.blue)
                            Text("Tags")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(content.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                
                // Sentiment & Metadata Row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "heart")
                                .foregroundColor(sentimentColor)
                            Text("Sentiment")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Text(content.sentiment.rawValue.capitalized)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(sentimentColor.opacity(0.15))
                            .foregroundColor(sentimentColor)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Created")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(content.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(content.createdAt, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Content Details")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingOriginalContent) {
            OriginalContentView(content: content.content)
        }
    }
    
    private var sentimentColor: Color {
        switch content.sentiment {
        case .positive:
            return .green
        case .negative:
            return .red
        case .neutral:
            return .gray
        }
    }
}

struct OriginalContentView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Original Content")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(content)
                        .font(.body)
                        .lineLimit(nil)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Original")
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