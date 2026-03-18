// AppState.swift — Global state management for the POS app
import SwiftUI
import LocalAuthentication

// MARK: - App Destination (navigation)
enum AppDestination: Equatable {
    case login
    case main
}

@Observable
@MainActor
final class AppState {

    static let shared = AppState()
    private let api = APIService.shared

    // MARK: Navigation
    var destination: AppDestination = .login
    var selectedTab: MainTab = .pos

    // MARK: Auth
    var currentUser: CurrentUser?
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    // MARK: Current Shift
    var currentShift: Shift?
    var shiftLoaded = false

    // MARK: Appearance
    var isDark: Bool = UserDefaults.standard.object(forKey: "pos_is_dark") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isDark, forKey: "pos_is_dark")
            AppTheme.isDark = isDark
        }
    }

    // MARK: Toast
    var toast: ToastMessage?

    // MARK: Spotlight deep-link
    var spotlightOrderId: String?

    // MARK: Biometric Lock
    var isBiometricEnabled: Bool = UserDefaults.standard.bool(forKey: "biometric_lock_enabled") {
        didSet { UserDefaults.standard.set(isBiometricEnabled, forKey: "biometric_lock_enabled") }
    }
    var isLocked: Bool = false

    func unlockWithBiometric() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            isLocked = false  // no biometrics enrolled — unlock anyway
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your POS terminal")
            if success { isLocked = false }
        } catch {
            // User cancelled or failed — stay locked
        }
    }

    private init() {
        AppTheme.isDark = isDark
        // Restore session if token exists
        if api.isAuthenticated {
            destination = .main
            Task { await loadInitialData() }
        }
    }

    // MARK: Login
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await api.login(email: email, password: password)
            api.accessToken = token.accessToken
            api.refreshToken = token.refreshToken
            api.tenantSlug = token.tenantSlug
            currentUser = CurrentUser(from: token)
            await loadInitialData()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                destination = .main
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loginWithPIN(email: String, pin: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await api.loginWithPIN(email: email, pin: pin)
            api.accessToken = token.accessToken
            api.refreshToken = token.refreshToken
            api.tenantSlug = token.tenantSlug
            currentUser = CurrentUser(from: token)
            await loadInitialData()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                destination = .main
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        api.logout()
        api.tenantSlug = nil
        currentUser = nil
        currentShift = nil
        shiftLoaded = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            destination = .login
        }
    }

    // MARK: Load initial data
    private func loadInitialData() async {
        await loadCurrentShift()
    }

    func loadCurrentShift() async {
        do {
            currentShift = try await api.getCurrentShift()
            // Persist for offline use
            if let shift = currentShift,
               let data = try? JSONEncoder().encode(shift) {
                UserDefaults.standard.set(data, forKey: "cached_current_shift")
            }
        } catch {
            // Offline fallback: load last known shift from cache
            if let data = UserDefaults.standard.data(forKey: "cached_current_shift"),
               let cached = try? JSONDecoder().decode(Shift.self, from: data) {
                currentShift = cached
            } else {
                currentShift = nil
            }
        }
        shiftLoaded = true
    }

    // MARK: Toast helpers
    func showSuccess(_ msg: String) {
        toast = ToastMessage(type: .success, text: msg)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.toast = nil
        }
    }

    func showError(_ msg: String) {
        toast = ToastMessage(type: .error, text: msg)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.toast = nil
        }
    }
}

// MARK: - Current User
struct CurrentUser {
    let userId: String
    let nameEn: String
    let nameAr: String
    let role: String
    let tenantId: String?
    let tenantSlug: String?

    init(from token: TokenResponse) {
        userId = token.userId
        nameEn = token.nameEn
        nameAr = token.nameAr
        role = token.role
        tenantId = token.tenantId
        tenantSlug = token.tenantSlug
    }

    var isManager: Bool { role == "manager" || role == "owner" || role == "super_admin" }
    var displayName: String { nameEn }
    var roleDisplayName: String { role.replacingOccurrences(of: "_", with: " ").capitalized }
}

// MARK: - Main Tabs
enum MainTab: String, CaseIterable {
    case pos      = "POS"
    case orders   = "Orders"
    case tables   = "Tables"
    case shift    = "Shift"
    case reports  = "Reports"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .pos:      return "cart.fill"
        case .orders:   return "list.bullet.clipboard.fill"
        case .tables:   return "table.furniture.fill"
        case .shift:    return "clock.badge.fill"
        case .reports:  return "chart.bar.xaxis"
        case .settings: return "gearshape.2.fill"
        }
    }

    var localizedName: String {
        L10n.shared.tabName(self.rawValue)
    }
}

// MARK: - Toast
struct ToastMessage: Identifiable {
    let id = UUID()
    enum ToastType { case success, error, info }
    let type: ToastType
    let text: String

    var color: Color {
        switch type {
        case .success: return AppTheme.success
        case .error:   return AppTheme.danger
        case .info:    return AppTheme.info
        }
    }
    var icon: String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }
}

// MARK: - Toast Overlay
struct ToastOverlay: View {
    let toast: ToastMessage
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: toast.icon)
                    .foregroundColor(toast.color)
                    .font(.system(size: 20, weight: .semibold))
                Text(toast.text)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(toast.color.opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
