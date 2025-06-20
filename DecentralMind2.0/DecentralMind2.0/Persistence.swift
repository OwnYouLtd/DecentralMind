import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Create sample data for previews if needed
        for _ in 0..<10 {
            let newItem = ContentEntity(context: viewContext)
            newItem.createdAt = Date()
            newItem.id = UUID()
            newItem.content = "Sample content"
            newItem.contentType = "text"
        }
        do {
            try viewContext.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // The name here MUST match your .xcdatamodeld file name.
        container = NSPersistentContainer(name: "DecentralMind")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Make store loading safer
        var loadError: Error?
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                loadError = error
            }
        })
        
        // If there was an error, try to recover by removing the store and creating a new one
        if loadError != nil {
            print("Attempting to recover from Core Data error...")
            // Remove problematic store files
            if let storeURL = container.persistentStoreDescriptions.first?.url {
                try? FileManager.default.removeItem(at: storeURL)
                // Try loading again
                container.loadPersistentStores { _, error in
                    if let error = error {
                        print("Recovery failed: \(error)")
                    } else {
                        print("Core Data recovery successful")
                    }
                }
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
} 