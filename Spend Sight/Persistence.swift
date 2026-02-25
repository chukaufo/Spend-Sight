//
//  Persistence.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-04.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    /// Preview container for SwiftUI previews (in-memory store).
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        // IMPORTANT: Removed template sample data that created `Item`,
        // since you deleted the Item entity.
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Spend_Sight")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

