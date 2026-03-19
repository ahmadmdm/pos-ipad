// CustomerDisplayView.swift — Branded customer-facing screen for external USB-C display
// Mirrors the current cart live and shows a ZATCA QR placeholder when order is paid.
import SwiftUI

// MARK: - External Display Manager
@MainActor
final class ExternalDisplayManager {
    static let shared = ExternalDisplayManager()
    private init() {}

    private var externalWindow: UIWindow?
    private var monitorTask: Task<Void, Never>?

    func start(posVM: POSViewModel) {
        // Handle any screen already connected at launch
        for screen in UIScreen.screens where screen !== UIScreen.main {
            showCustomerDisplay(on: screen, posVM: posVM)
        }
        // Observe future screen connections / disconnections
        monitorTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await notification in NotificationCenter.default.notifications(named: UIScreen.didConnectNotification) {
                        guard let screen = notification.object as? UIScreen else { continue }
                        await self?.showCustomerDisplay(on: screen, posVM: posVM)
                    }
                }
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(named: UIScreen.didDisconnectNotification) {
                        await self?.tearDown()
                    }
                }
            }
        }
    }

    private func showCustomerDisplay(on screen: UIScreen, posVM: POSViewModel) {
        let window = UIWindow(frame: screen.bounds)
        window.screen = screen
        let host = UIHostingController(
            rootView: CustomerDisplayView()
                .environment(posVM)
                .environment(AppState.shared)
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        externalWindow = window
    }

    private func tearDown() {
        externalWindow?.isHidden = true
        externalWindow = nil
    }
}

// MARK: - Customer Display View
struct CustomerDisplayView: View {
    @Environment(POSViewModel.self) var vm
    @Environment(AppState.self) var appState

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0A0A0F"), Color(hex: "0F1629")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if vm.isEmpty {
                welcomeScreen
            } else {
                orderScreen
            }
        }
    }

    // MARK: Welcome
    private var welcomeScreen: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 160, height: 160)
                Image(systemName: "storefront.fill")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(AppTheme.accentGrad)
            }
            VStack(spacing: 12) {
                Text("Welcome")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("مرحباً بك")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text("Powered by AMPOS")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 32)
        }
    }

    // MARK: Order summary
    private var orderScreen: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text("AMPOS")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.accentGrad)
                Spacer()
                if let table = vm.selectedTable {
                    Label("Table \(table.number)", systemImage: "table.furniture.fill")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.04))

            // Items
            ScrollView(showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(vm.cartItems) { item in
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.product.nameAr)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(item.product.nameEn)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            Text("×\(item.quantity)")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(AppTheme.accent)
                            Text(item.lineTotal.sarFormatted)
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.03))
                    }
                }
                .padding(.top, 8)
            }

            Spacer()

            // Totals
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                VStack(spacing: 16) {
                    HStack {
                        Text("Subtotal")
                            .font(.system(size: 18, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(vm.cartSubtotal.sarFormatted)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    if vm.discountAmount > 0 {
                        HStack {
                            Text("Discount")
                                .font(.system(size: 18, design: .rounded))
                                .foregroundColor(AppTheme.success.opacity(0.85))
                            Spacer()
                            Text("-\(vm.discountAmount.sarFormatted)")
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(AppTheme.success)
                        }
                    }
                    HStack {
                        Text("VAT (15%)")
                            .font(.system(size: 18, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(vm.cartVAT.sarFormatted)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Total")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text(vm.cartTotal.sarFormatted)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.accentGrad)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 28)
            }
            .background(Color.white.opacity(0.04))
        }
    }
}
