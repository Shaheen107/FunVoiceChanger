//
//  FunVoiceChangerApp.swift
//  FunVoiceChanger
//
//  Created by Dev Reptech on 10/02/2024.
//

import SwiftUI

@main
struct FunVoiceChangerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
