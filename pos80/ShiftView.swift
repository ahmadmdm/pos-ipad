// ShiftView.swift — Shift management: open, close, cash reconciliation
import SwiftUI

struct ShiftView: View {
    @EnvironmentObject var appState: AppState
    @State private var openingCash = ""
    @State private var closingCash = ""
    @State private var shiftNotes = ""
    @State private var isProcessing = false
    @State private var shiftHistory: [Shift] = []
    @State private var isLoadingHistory = false
    @State private var showCloseConfirm = false
    @State private var selectedShift: Shift?
    @State private var shiftSummary: Shift?

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
        }
        .onAppear {
            Task { await appState.loadCurrentShift() }
        }
    }

    // MARK: - Current Shift Panel
    private var currentShiftPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shift Management")
                        .font(AppTheme.title2())
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Manage your cashier shift")
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
                    Text("Shift Active")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.success)
                    if let openedAt = shift.openedAt {
                        Text("Opened at \(formatTime(openedAt))")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                Spacer()
                PillBadge(text: "LIVE", color: AppTheme.success)
            }
            .padding(16)
            .background(AppTheme.success.opacity(0.06))
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.success.opacity(0.2), lineWidth: 1))

            // Stats
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ShiftStatCard(label: "Opening Cash",
                              value: shift.openingCash.sarFormatted,
                              icon: "banknote.fill", color: AppTheme.success)
                ShiftStatCard(label: "Total Sales",
                              value: (shift.totalSales ?? 0).sarFormatted,
                              icon: "chart.line.uptrend.xyaxis", color: AppTheme.accent)
                ShiftStatCard(label: "Total Orders",
                              value: "\(shift.totalOrders ?? 0)",
                              icon: "cart.fill", color: AppTheme.info)
                ShiftStatCard(label: "Cash Sales",
                              value: (shift.cashSales ?? 0).sarFormatted,
                              icon: "banknote", color: AppTheme.warning)
            }

            // Close shift section
            VStack(alignment: .leading, spacing: 12) {
                Text("Close Shift")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                ThemeTextField(
                    icon: "banknote.fill",
                    placeholder: "Closing cash amount",
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
                        Text("Cash Difference:")
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
                    showCloseConfirm = true
                } label: {
                    Label(isProcessing ? "Processing..." : "Close Shift", systemImage: "xmark.circle.fill")
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
        }
        .confirmation(isPresented: $showCloseConfirm,
                      title: "Close Shift",
                      message: "Are you sure you want to close the current shift?",
                      destructiveLabel: "Close Shift") {
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
                Text("No Active Shift")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)
                Text("Open a shift to start accepting orders")
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(AppTheme.warning.opacity(0.05))
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(AppTheme.warning.opacity(0.2), lineWidth: 1))

            // Opening cash
            VStack(alignment: .leading, spacing: 12) {
                Text("Opening Cash Amount")
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
                        Label("Open Shift", systemImage: "clock.badge.checkmark.fill")
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
                Text("Shift History")
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
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

            if shiftHistory.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textMuted)
                    Text("No shift history")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(shiftHistory) { shift in
                            ShiftHistoryRow(shift: shift, isSelected: selectedShift?.id == shift.id) {
                                selectedShift = shift
                                Task { await loadShiftSummary(shift.id) }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Actions
    private func openShift() async {
        isProcessing = true
        let amount = Double(openingCash) ?? 0
        do {
            let shift = try await api.openShift(openingCash: amount)
            appState.currentShift = shift
            openingCash = ""
            appState.showSuccess("Shift opened successfully")
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
            shiftHistory.insert(closed, at: 0)
            appState.showSuccess("Shift closed. Total sales: \((closed.totalSales ?? 0).sarFormatted)")
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

    private func loadShiftHistory() async {
        isLoadingHistory = true
        do {
            struct ShiftHistoryResponse: Codable {
                let items: [Shift]
            }
            let resp: ShiftHistoryResponse = try await api.request(path: "/shifts/history")
            shiftHistory = resp.items
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
