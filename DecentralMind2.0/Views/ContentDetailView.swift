import SwiftUI

struct ContentDetailView: View {
    let content: ContentEntity
    
    var body: some View {
        VStack {
            Text(content.summary ?? "Detail View")
        }
        .navigationTitle(content.summary ?? "Content")
    }
} 