// ShiftView.swift — Shift management: open, close, cash reconciliation
import SwiftUI

private enum ShiftApprovalAction {
    case cashDrop
    case closeShift
}

struct ShiftView: View {
    @Environment(AppState.self) var appState
    private let l10n = L10n.shared
    @State private var openingCash = ""
    @State private var closingCash = ""
    @State private var shiftNotes = ""
    @State private var cashDropAmount = ""
    @State private var cashDropNotes = ""
    @State private var isProcessing = false
    @State private var shiftHistory: [Shift] = []
    @State private var isLoadingHistory = false
    @State private var showCloseConfirm = false
    @State private var selectedShift: Shift?
    @State private var shiftSummary: ShiftSummary?
    @State private var showManagerApproval = false
    @State private var pendingApprovalAction: ShiftApprovalAction?

    private let api = APIService.shared

    var body: some View {
        HStack(spacing: 0) {
            // Left: Current shift panel
            currentShiftPanel
                .frame(maxWidth: 400)
                .background(AppTheme.bg)

            // Right: History / Summary
            rightPanel
                .background(AppTheme.surface)
                .overlay(alignment: .leading) {
                    Rectangle().fill(AppTheme.border).frame(width: 1)
                }
        }
        .task {
            await loadShiftHistory()
            Task { await appState.loadCurrentShift() }
            if selectedShift == nil, let shift = appState.currentShift {
                selectedShift = shift
                await loadShiftSummary(shift.id)
            }
        }
        .sheet(isPresented: $showManagerApproval) {
            if let pendingApprovalAction {
                ManagerApprovalSheet(
                    actionTitle: approvalTitle(for: pendingApprovalAction),
                    message: l10n.managerApprovalRequired
                ) { _ in
                    handleApprovedAction(pendingApprovalAction)
                }
            }
        }
    }

    // MARK: - Current Shift Panel
    private var currentShiftPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("OPERATIONS")
                        .font(AppTheme.caption(11))
                        .tracking(2)
                        .foregroundColor(AppTheme.accent)
                    Text(l10n.shiftManagement)
                        .font(AppTheme.title2())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(l10n.manageShift)
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let shift = appState.currentShift {
                    activeShiftCard(shift: shift)
                } else {
                    openShiftCard
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [AppTheme.bg, Color(hex: "F8EFE4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        )
    }

    // MARK: - Active Shift Card
    private func activeShiftCard(shift: Shift) -> some View {
        VStack(spacing: 16) {
            // Status banner
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.success)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(AppTheme.success.opacity(0.3), lineWidth: 3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.shiftActive)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.success)
                    if let openedAt = shift.openedAt {
                        Text("\(l10n.opened) \(formatTime(openedAt))")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                Spacer()
                PillBadge(text: l10n.live, color: AppTheme.success)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [AppTheme.success.opacity(0.08), AppTheme.card],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            )
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.success.opacity(0.2), lineWidth: 1))
            .shadow(color: AppTheme.success.opacity(0.12), radius: 16, y: 8)

            // Stats
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ShiftStatCard(label: l10n.openingCash,
                              value: shift.openingCash.sarFormatted,
                              icon: "banknote.fill", color: AppTheme.success)
                ShiftStatCard(label: l10n.totalSales,
                              value: (shift.totalSales ?? 0).sarFormatted,
                              icon: "chart.line.uptrend.xyaxis", color: AppTheme.accent)
                ShiftStatCard(label: l10n.totalOrders,
                              value: "\(shift.totalOrders ?? 0)",
                              icon: "cart.fill", color: AppTheme.info)
                ShiftStatCard(label: l10n.cashSales,
                              value: (shift.cashSales ?? 0).sarFormatted,
                              icon: "banknote", color: AppTheme.warning)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(l10n.cashDrop)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                ThemeTextField(
                    icon: "tray.and.arrow.down.fill",
                    placeholder: l10n.cashDropAmount,
                    text: $cashDropAmount,
                    keyboardType: .decimalPad)

                TextEditor(text: $cashDropNotes)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.card)
                    .frame(height: 72)
                    .cornerRadius(AppTheme.r12)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                        .strokeBorder(AppTheme.border, lineWidth: 1))

                Button {
                    requestApproval(for: .cashDrop, shift: shift)
                } label: {
                    Label(isProcessing ? l10n.processing : l10n.recordCashDrop, systemImage: "tray.and.arrow.down.fill")
                        .font(AppTheme.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(hex: "B45309"))
                        .cornerRadius(AppTheme.r12)
                }
                .buttonStyle(.plain)
                .disabled((Double(cashDropAmount) ?? 0) <= 0 || isProcessing)
                .opacity((Double(cashDropAmount) ?? 0) <= 0 ? 0.5 : 1)
            }
            .themeCard()

            // Close shift section
            VStack(alignment: .leading, spacing: 12) {
                Text(l10n.closeShift)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                ThemeTextField(
                    icon: "banknote.fill",
                    placeholder: l10n.closingCash,
                    text: $closingCash,
                    keyboardType: .decimalPad)

                TextEditor(text: $shiftNotes)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.card)
                    .frame(height: 80)
                    .cornerRadius(AppTheme.r12)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                        .strokeBorder(AppTheme.border, lineWidth: 1))

                // Difference
                if let closing = Double(closingCash) {
                    let diff = closing - (shift.cashSales ?? 0)
                    HStack {
                        Text(l10n.cashDifference)
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text(diff.sarFormatted)
                            .font(AppTheme.headline())
                            .foregroundColor(diff >= 0 ? AppTheme.success : AppTheme.danger)
                    }
                    .padding(12)
                    .background(AppTheme.card)
                    .cornerRadius(AppTheme.r8)
                }

                Button {
                    requestApproval(for: .closeShift, shift: shift)
                } label: {
                    Label(isProcessing ? l10n.processing : l10n.closeShift, systemImage: "xmark.circle.fill")
                        .font(AppTheme.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.danger)
                        .cornerRadius(AppTheme.r12)
                }
                .buttonStyle(.plain)
                .disabled(closingCash.isEmpty || isProcessing)
                .opacity(closingCash.isEmpty ? 0.5 : 1)
            }
            .themeCard()
        }
        .confirmation(isPresented: $showCloseConfirm,
                      title: l10n.closeShiftConfirmTitle,
                      message: l10n.closeShiftConfirmMsg,
                      destructiveLabel: l10n.closeShift) {
            Task { await closeShift(shift: shift) }
        }
    }

    // MARK: - Open Shift Card
    private var openShiftCard: some View {
        VStack(spacing: 20) {
            // Illustration
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.warning.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.warning)
                }
                Text(l10n.noActiveShift)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)
                Text(l10n.openShiftCTA)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                LinearGradient(
                    colors: [AppTheme.warning.opacity(0.08), AppTheme.card],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            )
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(AppTheme.warning.opacity(0.2), lineWidth: 1))
            .shadow(color: AppTheme.warning.opacity(0.12), radius: 18, y: 8)

            // Opening cash
            VStack(alignment: .leading, spacing: 12) {
                Text(l10n.openingCashAmount)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                ThemeTextField(
                    icon: "banknote.fill",
                    placeholder: "0.00",
                    text: $openingCash,
                    keyboardType: .decimalPad)

                // Quick presets
                HStack(spacing: 8) {
                    ForEach([0, 200, 500, 1000], id: \.self) { amount in
                        Button {
                            openingCash = "\(amount)"
                        } label: {
                            Text(amount == 0 ? "Empty" : "\(amount)")
                                .font(AppTheme.caption())
                                .foregroundColor(openingCash == "\(amount)" ? .white : AppTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(openingCash == "\(amount)" ? AppTheme.accent : AppTheme.card)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(AppTheme.border, lineWidth: 1))
                        }
                    }
                }
            }

            Button {
                Task { await openShift() }
            } label: {
                ZStack {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Label(l10n.openShift, systemImage: "clock.badge.checkmark.fill")
                            .font(AppTheme.headline())
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.accentGradH)
                .cornerRadius(AppTheme.r16)
                .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
    }

    // MARK: - Right Panel
    private var rightPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AUDIT TRAIL")
                        .font(AppTheme.caption(11))
                        .tracking(2)
                        .foregroundColor(AppTheme.accent)
                    Text(l10n.shiftHistory)
                        .font(AppTheme.title2())
                        .foregroundColor(AppTheme.textPrimary)
                }
                Spacer()
                if isLoadingHistory {
                    ProgressView().tint(AppTheme.accent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }

            if shiftHistory.isEmpty && shiftSummary == nil {
                VStack {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textMuted)
                    Text(l10n.noShiftHistory)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if let shiftSummary {
                            shiftSummaryCard(shiftSummary)
                        }

                        LazyVStack(spacing: 8) {
                        ForEach(shiftHistory) { shift in
                            ShiftHistoryRow(shift: shift, isSelected: selectedShift?.id == shift.id) {
                                selectedShift = shift
                                Task { await loadShiftSummary(shift.id) }
                            }
                        }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [AppTheme.surface, Color(hex: "F2E7D8")],
                startPoint: .top,
                endPoint: .bottom)
        )
    }

    private func shiftSummaryCard(_ summary: ShiftSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.openedAt.map(formatTime) ?? l10n.shift_word)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textPrimary)
                    Text((summary.status ?? "open").capitalized)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Text((summary.totalSales ?? 0).sarFormatted)
                    .font(AppTheme.title2(20))
                    .foregroundColor(AppTheme.textPrimary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ShiftStatCard(label: l10n.totalOrders, value: "\(summary.totalOrders ?? 0)", icon: "cart.fill", color: AppTheme.info)
                ShiftStatCard(label: l10n.vat, value: (summary.totalVat ?? 0).sarFormatted, icon: "percent", color: AppTheme.warning)
                ShiftStatCard(label: l10n.cashSales, value: (summary.totalCashSales ?? 0).sarFormatted, icon: "banknote.fill", color: AppTheme.success)
                ShiftStatCard(label: l10n.card, value: (summary.totalCardSales ?? 0).sarFormatted, icon: "creditcard.fill", color: AppTheme.accent)
            }

            if summary.expectedCash != nil || summary.cashDifference != nil {
                HStack(spacing: 10) {
                    cashSummaryTile(title: "Expected", value: (summary.expectedCash ?? 0).sarFormatted, color: AppTheme.info)
                    cashSummaryTile(title: l10n.cashDifference, value: (summary.cashDifference ?? 0).sarFormatted, color: (summary.cashDifference ?? 0) >= 0 ? AppTheme.success : AppTheme.danger)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(l10n.cashDropHistory)
                    .font(AppTheme.headline(14))
                    .foregroundColor(AppTheme.textSecondary)

                if summary.cashDrops.isEmpty {
                    Text(l10n.noCashDrops)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                } else {
                    ForEach(summary.cashDrops) { drop in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(drop.amount.sarFormatted)
                                    .font(AppTheme.headline(13))
                                    .foregroundColor(AppTheme.textPrimary)
                                if let notes = drop.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(AppTheme.caption(11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            Spacer()
                            Text(drop.createdAt.map(formatTime) ?? "-")
                                .font(AppTheme.caption(11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .padding(12)
                        .background(AppTheme.cardHover)
                        .cornerRadius(AppTheme.r12)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r16)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
            .strokeBorder(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.shadow.opacity(0.75), radius: 18, y: 8)
    }

    // MARK: - Actions
    private func openShift() async {
        isProcessing = true
        let amount = Double(openingCash) ?? 0
        do {
            let shift = try await api.openShift(openingCash: amount)
            appState.currentShift = shift
            openingCash = ""
            appState.showSuccess(l10n.shiftOpened())
            // Schedule shift-end reminder (8-hour expected duration)
            NotificationManager.shared.scheduleShiftEndReminder(
                shiftId: shift.id,
                shiftOpenDate: Date()
            )
        } catch {
            appState.showError(error.localizedDescription)
        }
        isProcessing = false
    }

    private func closeShift(shift: Shift) async {
        guard let closing = Double(closingCash) else { return }
        isProcessing = true
        do {
            let closed = try await api.closeShift(shiftId: shift.id, closingCash: closing, notes: shiftNotes.isEmpty ? nil : shiftNotes)
            appState.currentShift = nil
            closingCash = ""
            shiftNotes = ""
            cashDropAmount = ""
            cashDropNotes = ""
            shiftHistory.insert(closed, at: 0)
            appState.showSuccess(l10n.shiftClosed((closed.totalSales ?? 0).sarFormatted))
            // Cancel pending shift reminder
            NotificationManager.shared.cancelShiftReminders(shiftId: shift.id)
        } catch {
            // Sync with server — shift may have been closed remotely
            await appState.loadCurrentShift()
            if appState.currentShift == nil {
                // It was already closed — treat as success
                closingCash = ""
                shiftNotes = ""
                appState.showSuccess("Shift closed.")
                await loadShiftHistory()
            } else {
                appState.showError(error.localizedDescription)
            }
        }
        isProcessing = false
    }

    private func addCashDrop(shift: Shift) async {
        guard let amount = Double(cashDropAmount), amount > 0 else { return }
        isProcessing = true
        do {
            try await api.addCashDrop(shiftId: shift.id, amount: amount, notes: cashDropNotes.isEmpty ? nil : cashDropNotes)
            cashDropAmount = ""
            cashDropNotes = ""
            await appState.loadCurrentShift()
            if selectedShift?.id == shift.id {
                await loadShiftSummary(shift.id)
            }
            appState.showSuccess(l10n.cashDropRecorded(amount.sarFormatted))
        } catch {
            appState.showError(error.localizedDescription)
        }
        isProcessing = false
    }

    private func loadShiftHistory() async {
        isLoadingHistory = true
        do {
            let resp: [Shift] = try await api.request(path: "/shifts/history")
            shiftHistory = resp
        } catch {}
        isLoadingHistory = false
    }

    private func loadShiftSummary(_ id: String) async {
        do {
            shiftSummary = try await api.getShiftSummary(id)
        } catch {}
    }

    private func formatTime(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) else { return iso }
        let d = DateFormatter()
        d.dateFormat = "HH:mm - dd MMM"
        return d.string(from: date)
    }

    private func cashSummaryTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.caption(11))
                .foregroundColor(AppTheme.textMuted)
            Text(value)
                .font(AppTheme.headline(13))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(AppTheme.r12)
    }

    private func requestApproval(for action: ShiftApprovalAction, shift: Shift) {
        if appState.currentUser?.isManager ?? false {
            handleAction(action, shift: shift)
            return
        }
        selectedShift = shift
        pendingApprovalAction = action
        showManagerApproval = true
    }

    private func handleApprovedAction(_ action: ShiftApprovalAction) {
        guard let shift = selectedShift ?? appState.currentShift else { return }
        pendingApprovalAction = nil
        handleAction(action, shift: shift)
    }

    private func handleAction(_ action: ShiftApprovalAction, shift: Shift) {
        switch action {
        case .cashDrop:
            Task { await addCashDrop(shift: shift) }
        case .closeShift:
            showCloseConfirm = true
        }
    }

    private func approvalTitle(for action: ShiftApprovalAction) -> String {
        switch action {
        case .cashDrop:
            return l10n.cashDropApproval
        case .closeShift:
            return l10n.closeShiftApproval
        }
    }
}

// MARK: - Shift Stat Card
struct ShiftStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .cornerRadius(8)

            Text(value)
                .font(AppTheme.headline(16))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(AppTheme.caption())
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r12)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
            .strokeBorder(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.shadow.opacity(0.55), radius: 12, y: 6)
    }
}

// MARK: - Shift History Row
struct ShiftHistoryRow: View {
    let shift: Shift
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(shift.status == "closed" ? AppTheme.textMuted : AppTheme.success)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.openedAt.map { formatShiftDate($0) } ?? "Shift")
                        .font(AppTheme.headline(14))
                        .foregroundColor(AppTheme.textPrimary)
                    HStack(spacing: 8) {
                        Text("\(shift.totalOrders ?? 0) orders")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                        Text("•")
                            .foregroundColor(AppTheme.textMuted)
                        PillBadge(text: (shift.status ?? "open").capitalized,
                                  color: shift.status == "closed" ? AppTheme.textSecondary : AppTheme.success)
                    }
                }

                Spacer()

                Text((shift.totalSales ?? 0).sarFormatted)
                    .font(AppTheme.mono(14))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(14)
            .background(isSelected ? AppTheme.accent.opacity(0.08) : AppTheme.card)
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(isSelected ? AppTheme.accent.opacity(0.4) : AppTheme.border, lineWidth: 1))
            .shadow(color: isSelected ? AppTheme.accent.opacity(0.08) : AppTheme.shadow.opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func formatShiftDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) else { return iso }
        let d = DateFormatter()
        d.dateFormat = "dd MMM - HH:mm"
        return d.string(from: date)
    }
}

// MARK: - Confirmation Modifier
extension View {
    func confirmation(isPresented: Binding<Bool>,
                      title: String,
                      message: String,
                      destructiveLabel: String,
                      action: @escaping () -> Void) -> some View {
        self.alert(title, isPresented: isPresented) {
            Button(destructiveLabel, role: .destructive) { action() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
