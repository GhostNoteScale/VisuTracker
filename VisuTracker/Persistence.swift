import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "VisuTracker")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // App Groups用のURL設定
            let appGroupIdentifier = "group.work.rockets.VisuTracker2"
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
                fatalError("Failed to get container URL for App Group: \(appGroupIdentifier)")
            }
            let storeURL = containerURL.appendingPathComponent("VisuTracker.sqlite")
            
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("❌ Core Data error: \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("✅ Core Data loaded successfully")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// MARK: - Preview Data
extension PersistenceController {
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // プレビュー用のサンプルデータを作成
        let newItem = VisuItem(context: viewContext)
        newItem.id = UUID()
        newItem.timestamp = Date()
        newItem.productName = "プレビュー商品"
        newItem.price = "¥1,500"
        newItem.pageURL = "https://example.com"
        newItem.imageURL = "https://img.icons8.com/color/300/clothes.png"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
}
