// ReservationsView.swift — Reservations Management
import SwiftUI

struct ReservationsView: View {
    @EnvironmentObject var appState: AppState
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var reservations: [Reservation] = []
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var editingReservation: Reservation?
    @State private var filterStatus: String?
    @State private var filterDate: Date = Date()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            filters

            if isLoading {
                Spacer(); ProgressView(); Spacer()
            } else if reservations.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock").font(.system(size: 40)).foregroundColor(AppTheme.textMuted)
                    Text(l10n.noReservations).font(AppTheme.body(15)).foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(reservations) { r in
                            reservationRow(r)
                        }
                    }.padding(20)
                }
            }
        }
        .background(AppTheme.bgGradient.ignoresSafeArea())
        .task { await load() }
        .sheet(isPresented: $showAdd) { ReservationFormSheet(reservation: nil, onSave: { await load() }) }
        .sheet(item: $editingReservation) { r in ReservationFormSheet(reservation: r, onSave: { await load() }) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.reservations).font(AppTheme.title2(22)).foregroundColor(AppTheme.textPrimary)
                Text(l10n.reservationsSubtitle).font(AppTheme.caption(13)).foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            Button { showAdd = true } label: {
                Label(l10n.addReservation, systemImage: "plus.circle.fill")
                    .font(AppTheme.caption(13)).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(AppTheme.accentGrad).cornerRadius(AppTheme.r12)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DatePicker("", selection: $filterDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: filterDate) { _ in Task { await load() } }

                ForEach(["all", "pending", "confirmed", "seated", "completed", "cancelled", "no_show"], id: \.self) { status in
                    Button {
                        filterStatus = status == "all" ? nil : status
                        Task { await load() }
                    } label: {
                        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(AppTheme.caption(11))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background((filterStatus == status || (filterStatus == nil && status == "all")) ? AppTheme.accent : AppTheme.surface)
                            .foregroundColor((filterStatus == status || (filterStatus == nil && status == "all")) ? .white : AppTheme.textPrimary)
                            .cornerRadius(999)
                    }
                }
            }.padding(.horizontal, 20)
        }.padding(.bottom, 8)
    }

    private func reservationRow(_ r: Reservation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(r.customerName ?? "-").font(AppTheme.body(15)).foregroundColor(AppTheme.textPrimary)
                    if let status = r.status {
                        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(AppTheme.caption(10))
                            .foregroundColor(reservationStatusColor(status))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(reservationStatusColor(status).opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 12) {
                    if let phone = r.customerPhone {
                        Label(phone, systemImage: "phone.fill").font(AppTheme.caption(12)).foregroundColor(AppTheme.textSecondary)
                    }
                    if let time = r.reservationTime {
                        Label(time, systemImage: "clock.fill").font(AppTheme.caption(12)).foregroundColor(AppTheme.textSecondary)
                    }
                    if let size = r.partySize {
                        Label("\(size)", systemImage: "person.2.fill").font(AppTheme.caption(12)).foregroundColor(AppTheme.textSecondary)
                    }
                }
                if let notes = r.notes, !notes.isEmpty {
                    Text(notes).font(AppTheme.caption(11)).foregroundColor(AppTheme.textMuted).lineLimit(1)
                }
            }
            Spacer()
            Menu {
                Button(l10n.edit) { editingReservation = r }
                if r.status == "pending" {
                    Button(l10n.confirm) { Task { await updateStatus(r.id, "confirmed") } }
                }
                if r.status == "confirmed" {
                    Button(l10n.seat) { Task { await updateStatus(r.id, "seated") } }
                }
                if r.status == "seated" {
                    Button(l10n.complete) { Task { await updateStatus(r.id, "completed") } }
                }
                Button(l10n.cancel, role: .destructive) { Task { await updateStatus(r.id, "cancelled") } }
                Button(l10n.delete, role: .destructive) { Task { await deleteRes(r.id) } }
            } label: {
                Image(systemName: "ellipsis.circle.fill").font(.system(size: 22)).foregroundColor(AppTheme.accent)
            }
        }
        .padding(14)
        .background(AppTheme.card).cornerRadius(AppTheme.r12)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12).strokeBorder(AppTheme.border, lineWidth: 1))
    }

    private func reservationStatusColor(_ s: String) -> Color {
        switch s {
        case "pending": return AppTheme.warning
        case "confirmed": return AppTheme.info
        case "seated": return AppTheme.accent
        case "completed": return AppTheme.success
        case "cancelled", "no_show": return AppTheme.danger
        default: return AppTheme.textMuted
        }
    }

    private func load() async {
        isLoading = true
        let dateStr = dateFormatter.string(from: filterDate)
        reservations = (try? await api.fetchReservations(date: dateStr, status: filterStatus)) ?? []
        isLoading = false
    }

    private func updateStatus(_ id: String, _ status: String) async {
        _ = try? await api.updateReservation(id, body: ReservationUpdate(status: status, tableId: nil, reservationTime: nil, partySize: nil, notes: nil))
        await load()
    }

    private func deleteRes(_ id: String) async {
        try? await api.deleteReservation(id)
        await load()
    }
}

// MARK: - Reservation Form
struct ReservationFormSheet: View {
    let reservation: Reservation?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var customerName = ""
    @State private var customerPhone = ""
    @State private var date = ""
    @State private var time = ""
    @State private var partySize = ""
    @State private var notes = ""
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(l10n.customerInfo) {
                    TextField(l10n.customerName, text: $customerName)
                    TextField(l10n.customerPhone, text: $customerPhone).keyboardType(.phonePad)
                }
                Section(l10n.details) {
                    TextField(l10n.date, text: $date)
                    TextField(l10n.time, text: $time)
                    TextField(l10n.partySize, text: $partySize).keyboardType(.numberPad)
                    TextField(l10n.notes, text: $notes)
                }
            }
            .navigationTitle(reservation == nil ? l10n.addReservation : l10n.editReservation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.save) { Task { await save() } }.disabled(saving || customerName.isEmpty)
                }
            }
            .onAppear {
                if let r = reservation {
                    customerName = r.customerName ?? ""; customerPhone = r.customerPhone ?? ""
                    date = r.reservationDate ?? ""; time = r.reservationTime ?? ""
                    partySize = r.partySize.map { "\($0)" } ?? ""; notes = r.notes ?? ""
                }
            }
        }
    }

    private func save() async {
        saving = true
        if let r = reservation {
            let body = ReservationUpdate(
                status: nil, tableId: nil,
                reservationTime: time.isEmpty ? nil : time,
                partySize: Int(partySize),
                notes: notes.isEmpty ? nil : notes
            )
            _ = try? await api.updateReservation(r.id, body: body)
        } else {
            let body = ReservationCreate(
                customerName: customerName, customerPhone: customerPhone,
                reservationDate: date, reservationTime: time,
                partySize: Int(partySize) ?? 2,
                tableId: nil, notes: notes.isEmpty ? nil : notes
            )
            _ = try? await api.createReservation(body)
        }
        await onSave()
        saving = false
        dismiss()
    }
}
