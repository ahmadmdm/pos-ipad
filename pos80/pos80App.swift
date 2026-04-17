//
//  pos80App.swift
//  pos80
//
//  Created by ahmad almubarak on 14/03/2026.
//

import SwiftUI
import TipKit
import CoreSpotlight

// MARK: - Menu Bar Notification Names
extension Notification.Name {
    static let amposMenuNewOrder     = Notification.Name("ampos.menu.newOrder")
    static let amposMenuClearCart    = Notification.Name("ampos.menu.clearCart")
    static let amposMenuPrintReceipt = Notification.Name("ampos.menu.printReceipt")
}

// MARK: - App Entry Point
@main
struct pos80App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState.shared

    init() {
        APIConfig.migrateStoredBaseURLIfNeeded()
        if #available(iOS 17.0, *) {
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        }
        // Register background tasks early (before app finishes launching)
        BGRefreshManager.registerTasks()
        // Request notification permission (non-blocking)
        Task { await NotificationManager.shared.requestPermission() }
    }

    var body: some Scene {
        // MARK: Main window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.isDark ? .dark : .light)
                .task { await appState.refreshManagerSnapshot() }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                    appState.spotlightOrderId = id
                    appState.selectedTab = .orders
                    if appState.destination != .main { appState.destination = .main }
                }
                .onContinueUserActivity("com.ampos.pos80.viewOrder") { activity in
                    guard let orderId = activity.userInfo?["orderId"] as? String else { return }
                    appState.spotlightOrderId = orderId
                    appState.selectedTab = .orders
                    if appState.destination != .main { appState.destination = .main }
                }
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }
                    Task { await appState.refreshManagerSnapshot() }
                }
        }

        // MARK: Orders window (Stage Manager / External Display)
        WindowGroup("Orders", id: "orders") {
            OrdersView()
                .environmentObject(appState)
                .preferredColorScheme(appState.isDark ? .dark : .light)
        }
    }
}

// MARK: - App Delegate
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .landscape
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let state = AppState.shared
        switch shortcutItem.type {
        case "com.ampos.pos80.neworder":
            state.selectedTab = .pos
            state.destination = .main
        case "com.ampos.pos80.orders":
            state.selectedTab = .orders
            state.destination = .main
        case "com.ampos.pos80.reports":
            state.selectedTab = .reports
            state.destination = .main
        default:
            break
        }
        completionHandler(true)
    }

    // MARK: iPad Menu Bar (Mac Catalyst / Stage Manager)
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }

        // Remove built-in menus that don't apply to a POS kiosk
        builder.remove(menu: .format)
        builder.remove(menu: .font)
        builder.remove(menu: .textStyle)
        builder.remove(menu: .spelling)
        builder.remove(menu: .substitutions)
        builder.remove(menu: .transformations)
        builder.remove(menu: .speech)
        builder.remove(menu: .lookup)
        builder.remove(menu: .learn)

        // ── POS Actions menu ──────────────────────────────────────────────
        let newOrderCmd = UIKeyCommand(
            title: "New Order",
            image: UIImage(systemName: "cart.badge.plus"),
            action: #selector(menuNewOrder),
            input: "n",
            modifierFlags: .command
        )
        let clearCartCmd = UIKeyCommand(
            title: "Clear Cart",
            image: UIImage(systemName: "cart.badge.minus"),
            action: #selector(menuClearCart),
            input: "\u{8}",          // ⌘⌫
            modifierFlags: .command
        )
        let printCmd = UIKeyCommand(
            title: "Print Last Receipt",
            image: UIImage(systemName: "printer.fill"),
            action: #selector(menuPrintReceipt),
            input: "p",
            modifierFlags: .command
        )

        let posMenu = UIMenu(
            title: "POS",
            image: nil,
            identifier: UIMenu.Identifier("com.ampos.pos80.menu.pos"),
            options: [],
            children: [newOrderCmd, clearCartCmd, printCmd]
        )
        builder.insertSibling(posMenu, afterMenu: .application)
    }

    @objc private func menuNewOrder() {
        NotificationCenter.default.post(name: .amposMenuNewOrder, object: nil)
    }
    @objc private func menuClearCart() {
        NotificationCenter.default.post(name: .amposMenuClearCart, object: nil)
    }
    @objc private func menuPrintReceipt() {
        NotificationCenter.default.post(name: .amposMenuPrintReceipt, object: nil)
    }
}

struct CompatNavigationContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
                .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

extension View {
    @ViewBuilder
    func compatMediumLargeDetents() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large])
        } else {
            self
        }
    }

    @ViewBuilder
    func compatMediumDetent() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium])
        } else {
            self
        }
    }

    @ViewBuilder
    func compatFractionLargeDetents() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.fraction(0.7), .large])
        } else {
            self
        }
    }

    @ViewBuilder
    func compatVisiblePresentationDragIndicator() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatHiddenScrollContentBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatSheetNavigationChrome() -> some View {
        if #available(iOS 16.0, *) {
            self
                .toolbarBackground(AppTheme.surface, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatDraggable(_ value: String) -> some View {
        if #available(iOS 16.0, *) {
            self.draggable(value)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatStringDropDestination(action: @escaping ([String], CGPoint) -> Bool) -> some View {
        if #available(iOS 16.0, *) {
            self.dropDestination(for: String.self, action: action)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatKeyboardShortcutsTip() -> some View {
        if #available(iOS 17.0, *) {
            self.popoverTip(KeyboardShortcutsTip())
        } else {
            self
        }
    }

    @ViewBuilder
    func compatDragToCartTip() -> some View {
        if #available(iOS 17.0, *) {
            self.popoverTip(DragToCartTip())
        } else {
            self
        }
    }

    @ViewBuilder
    func compatOrderContextMenuTip() -> some View {
        if #available(iOS 17.0, *) {
            self.popoverTip(OrderContextMenuTip())
        } else {
            self
        }
    }
}

func makeTemporaryPDFURL(filename: String, data: Data) -> URL? {
    let safeName = filename.replacingOccurrences(of: "/", with: "-")
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
    do {
        try data.write(to: url, options: .atomic)
        return url
    } catch {
        return nil
    }
}

