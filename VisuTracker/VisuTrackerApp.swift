//
//  VisuTrackerApp.swift
//  VisuTracker
//
//  Created by Go Nakazawa on 2025/06/22.
//

import SwiftUI

@main
struct VisuTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
