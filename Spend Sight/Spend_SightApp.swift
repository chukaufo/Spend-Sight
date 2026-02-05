//
//  Spend_SightApp.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-04.
//

import SwiftUI
import CoreData

@main
struct Spend_SightApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
