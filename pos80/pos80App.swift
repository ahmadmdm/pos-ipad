//
//  pos80App.swift
//  pos80
//
//  Created by ahmad almubarak on 14/03/2026.
//

import SwiftUI

@main
struct pos80App: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.isDark ? .dark : .light)
        }
    }
}
