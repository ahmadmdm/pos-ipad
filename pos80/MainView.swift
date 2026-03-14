// MainView.swift — App shell with sidebar navigation
import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var posVM = POSViewModel()
    @State private var showShiftAlert = false
    @State private var sidebarHovered: MainTab?

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            HStack(spacing: 0) {
                // Sidebar
                sidebar

                // Content
                ZStack {
                    switch appState.selectedTab {
                    case .pos:      POSView().environmentObject(posVM)
                    case .orders:   OrdersView()
                    case .tables:   TablesView().environmentObject(posVM)
                    case .shift:    ShiftView()
                    case .reports:  ReportsView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Toast overlay
            if let toast = appState.toast {
                ToastOverlay(toast: toast)
                    .padding(.horizontal, 80)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: appState.toast?.id)
                    .zIndex(999)
            }
        }
        .task {
            await posVM.loadMenu()
            await posVM.loadTables()
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.accentGrad)
                        .frame(width: 48, height: 48)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("ampos")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [.white, Color(hex: "C4B5FD")],
                        startPoint: .leading, endPoint: .trailing))
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Shift badge
            if let shift = appState.currentShift {
                VStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 8, height: 8)
                    Text("Shift")
                        .font(AppTheme.caption(10))
                        .foregroundColor(AppTheme.success)
                    Text("#\(String(shift.id.prefix(6)))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.bottom, 12)
            } else {
                Button { appState.selectedTab = .shift } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.warning)
                            .frame(width: 8, height: 8)
                        Text("No Shift")
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.warning)
                    }
                }
                .padding(.bottom, 12)
            }

            Divider().background(AppTheme.border).padding(.horizontal, 12)
                .padding(.bottom, 16)

            // Navigation items
            VStack(spacing: 4) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    SidebarItem(
                        tab: tab,
                        isSelected: appState.selectedTab == tab,
                        badge: tab == .pos && posVM.cartCount > 0 ? "\(posVM.cartCount)" : nil
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appState.selectedTab = tab
                        }
                    }
                }
            }

            Spacer()

            // Bottom user info
            VStack(spacing: 16) {
                Divider().background(AppTheme.border).padding(.horizontal, 12)

                if let user = appState.currentUser {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accentGrad)
                                .frame(width: 36, height: 36)
                            Text(String(user.nameEn.prefix(1).uppercased()))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(user.displayName.components(separatedBy: " ").first ?? user.displayName)
                            .font(AppTheme.caption(11))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                        Text(user.roleDisplayName)
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Button {
                    appState.logout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.danger)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.danger.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 72)
        .background(AppTheme.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1)
        }
    }
}

// MARK: - Sidebar Item
struct SidebarItem: View {
    let tab: MainTab
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(isSelected ? AppTheme.accent.opacity(0.15) : Color.clear)
                        .cornerRadius(12)

                    Text(tab.rawValue)
                        .font(AppTheme.caption(10))
                        .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.danger)
                        .cornerRadius(10)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 60, height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
