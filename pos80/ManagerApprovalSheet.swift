import SwiftUI

struct ManagerApprovalResult {
    let manager: POSUserPreview
    let token: TokenResponse
}

struct ManagerApprovalSheet: View {
    let actionTitle: String
    let message: String
    let onApproved: (ManagerApprovalResult) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    private let l10n = L10n.shared

    @State private var managers: [POSUserPreview] = []
    @State private var selectedManagerId: String?
    @State private var pin = ""
    @State private var isLoadingManagers = false
    @State private var isApproving = false
    @State private var errorMessage: String?

    private var selectedManager: POSUserPreview? {
        managers.first(where: { $0.id == selectedManagerId })
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(actionTitle)
                        .font(AppTheme.title2())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(message)
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.textMuted)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n.selectManager)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)

                    if isLoadingManagers {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(l10n.loading)
                                .font(AppTheme.body())
                                .foregroundColor(AppTheme.textMuted)
                        }
                    } else if managers.isEmpty {
                        Text(l10n.managerApprovalRequired)
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textMuted)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(managers) { manager in
                                    Button {
                                        selectedManagerId = manager.id
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(l10n.isArabic ? (manager.nameAr.isEmpty ? manager.displayName : manager.nameAr) : manager.displayName)
                                                .font(AppTheme.headline(14))
                                                .foregroundColor(selectedManagerId == manager.id ? .white : AppTheme.textPrimary)
                                            Text(manager.role.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(AppTheme.caption(11))
                                                .foregroundColor(selectedManagerId == manager.id ? .white.opacity(0.8) : AppTheme.textMuted)
                                        }
                                        .padding(12)
                                        .frame(width: 180, alignment: .leading)
                                        .background(selectedManagerId == manager.id ? AppTheme.accent : AppTheme.card)
                                        .cornerRadius(AppTheme.r12)
                                        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                            .strokeBorder(selectedManagerId == manager.id ? AppTheme.accent : AppTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n.managerPin)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)

                    SecureField(l10n.managerPin, text: $pin)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppTheme.card)
                        .cornerRadius(AppTheme.r12)
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                            .strokeBorder(AppTheme.border, lineWidth: 1))
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.danger)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(l10n.cancel) { dismiss() }
                        .buttonStyle(GhostButtonStyle())

                    Button {
                        Task { await approve() }
                    } label: {
                        if isApproving {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(l10n.approve)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                    .disabled(selectedManager == nil || pin.isEmpty || isApproving)
                }
            }
            .padding(24)
            .background(AppTheme.bg)
            .task { await loadManagers() }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func loadManagers() async {
        isLoadingManagers = true
        defer { isLoadingManagers = false }
        do {
            managers = try await APIService.shared.fetchPOSUsers().filter(\.isManager)
            if selectedManagerId == nil {
                selectedManagerId = managers.first?.id
            }
        } catch {
            managers = []
            errorMessage = error.localizedDescription
        }
    }

    private func approve() async {
        guard let manager = selectedManager else { return }
        isApproving = true
        errorMessage = nil
        defer { isApproving = false }
        do {
            let token = try await APIService.shared.loginWithPIN(email: manager.email, pin: pin)
            guard CurrentUser(from: token).isManager else {
                errorMessage = l10n.managerApprovalRequired
                return
            }
            let displayName = l10n.isArabic ? (manager.nameAr.isEmpty ? manager.displayName : manager.nameAr) : manager.displayName
            appState.recordManagerApproval(action: actionTitle, managerName: displayName, managerRole: token.role)
            onApproved(ManagerApprovalResult(manager: manager, token: token))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}