import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataFlowManager: DataFlowManager

    init() {
        // This is a bit of a workaround to initialize a @StateObject
        // with a parameter from the environment.
        let context = PersistenceController.shared.container.viewContext
        _dataFlowManager = StateObject(wrappedValue: DataFlowManager(context: context))
    }

    var body: some View {
        StorachaTestView()
            .environmentObject(dataFlowManager)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}