import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        StorachaTestView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}