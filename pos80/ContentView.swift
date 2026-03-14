//
//  ContentView.swift
//  pos80
//
//  Created by ahmad almubarak on 14/03/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.destination {
            case .login:
                LoginView()
            case .main:
                MainView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.destination)
        .overlay(alignment: .bottom) {
            if let toast = appState.toast {
                ToastOverlay(toast: toast)
            }
        }
    }
}
