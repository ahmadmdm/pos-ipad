// AppState.swift — Global state management for the POS app
import SwiftUI
import Combine

// MARK: - App Destination (navigation)
enum AppDestination: Equatable {
    case login
    case main
}

@MainActor
final class AppState: ObservableObject {

    static let shared = AppState()
    private let api = APIService.shared

    // MARK: Navigation
    @Published var destination: AppDestination = .login
    @Published var selectedTab: MainTab = .pos

    // MARK: Auth
    @Published var currentUser: CurrentUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: Current Shift
    @Published var currentShift: Shift?
    @Published var shiftLoaded = false

    // MARK: Appearance
    @AppStorage("pos_is_dark") var isDark: Bool = true {
        didSet { AppTheme.isDark = isDark }
    }

    // MARK: Toast
    @Published var toast: ToastMessage?

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
        } catch {
            currentShift = nil
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
