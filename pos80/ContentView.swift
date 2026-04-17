//
//  ContentView.swift
//  pos80
//
//  Created by ahmad almubarak on 14/03/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { phase in
            if phase == .background,
               appState.destination == .main,
               appState.isBiometricEnabled {
                appState.isLocked = true
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { appState.isLocked },
            set: { if !$0 { appState.isLocked = false } }
        )) {
            BiometricLockScreen()
                .environmentObject(appState)
        }
    }
}

// MARK: - Biometric Lock Screen
struct BiometricLockScreen: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            VStack(spacing: 36) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundColor(AppTheme.accent)
                }
                VStack(spacing: 8) {
                    Text("POS Locked")
                        .font(AppTheme.title2())
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Authenticate to continue")
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                }
                Button {
                    Task { await appState.unlockWithBiometric() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Unlock with Face ID")
                            .font(AppTheme.headline())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(AppTheme.accentGrad)
                    .cornerRadius(AppTheme.r16)
                }
                Spacer()
            }
        }
        .task { await appState.unlockWithBiometric() }
    }
}
