//
//  StarterFileApp.swift
//  StarterFile
//
//  Created by Milo Ullman on 23/12/25.
//

import SwiftUI
import SwiftData

@main
struct CalculusPlaygroundApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Function.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            VStack {
                HomeView()
            }
            
        }.modelContainer(sharedModelContainer)
    }
}
