// StaffScheduleView.swift — Staff Schedule Management
import SwiftUI

struct StaffScheduleView: View {
    @EnvironmentObject var appState: AppState
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var schedules: [StaffSchedule] = []
    @State private var staff: [Staff] = []
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var editingSchedule: StaffSchedule?
    @State private var selectedDate = Date()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header

            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .frame(maxHeight: 300)
                .padding(.horizontal, 20)
                .onChange(of: selectedDate) { _ in Task { await load() } }

            if isLoading {
                Spacer(); ProgressView(); Spacer()
            } else if schedules.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus").font(.system(size: 40)).foregroundColor(AppTheme.textMuted)
                    Text(l10n.noSchedules).font(AppTheme.body(15)).foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(schedules) { schedule in
                            scheduleRow(schedule)
                        }
                    }.padding(20)
                }
            }
        }
        .background(AppTheme.bgGradient.ignoresSafeArea())
        .task {
            staff = (try? await api.fetchStaff()) ?? []
            await load()
        }
        .sheet(isPresented: $showAdd) { ScheduleFormSheet(schedule: nil, staff: staff, branchId: appState.currentUser?.branchId ?? "", onSave: { await load() }) }
        .sheet(item: $editingSchedule) { s in ScheduleFormSheet(schedule: s, staff: staff, branchId: appState.currentUser?.branchId ?? "", onSave: { await load() }) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.staffSchedules).font(AppTheme.title2(22)).foregroundColor(AppTheme.textPrimary)
                Text(l10n.staffSchedulesSubtitle).font(AppTheme.caption(13)).foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            Button { showAdd = true } label: {
                Label(l10n.addSchedule, systemImage: "plus.circle.fill")
                    .font(AppTheme.caption(13)).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(AppTheme.accentGrad).cornerRadius(AppTheme.r12)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    private func scheduleRow(_ s: StaffSchedule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.staffName ?? s.userId)
                    .font(AppTheme.body(15)).foregroundColor(AppTheme.textPrimary)
                if s.isDayOff {
                    Text(l10n.dayOff)
                        .font(AppTheme.caption(12)).foregroundColor(AppTheme.warning)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppTheme.warning.opacity(0.15)).cornerRadius(4)
                } else {
                    HStack(spacing: 8) {
                        Label(s.shiftStart, systemImage: "clock.fill")
                            .font(AppTheme.caption(12)).foregroundColor(AppTheme.success)
                        Text("→")
                            .font(AppTheme.caption(12)).foregroundColor(AppTheme.textMuted)
                        Text(s.shiftEnd)
                            .font(AppTheme.caption(12)).foregroundColor(AppTheme.danger)
                    }
                }
                if let notes = s.notes, !notes.isEmpty {
                    Text(notes).font(AppTheme.caption(11)).foregroundColor(AppTheme.textMuted).lineLimit(1)
                }
            }
            Spacer()
            Button { editingSchedule = s } label: {
                Image(systemName: "pencil.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.accent)
            }
            Button { Task { await deleteSchedule(s.id) } } label: {
                Image(systemName: "trash.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.danger)
            }
        }
        .padding(14)
        .background(AppTheme.card).cornerRadius(AppTheme.r12)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12).strokeBorder(AppTheme.border, lineWidth: 1))
    }

    private func load() async {
        isLoading = true
        let dateStr = dateFormatter.string(from: selectedDate)
        schedules = (try? await api.fetchSchedules(dateFrom: dateStr, dateTo: dateStr)) ?? []
        isLoading = false
    }

    private func deleteSchedule(_ id: String) async {
        try? await api.deleteSchedule(id)
        await load()
    }
}

// MARK: - Schedule Form
struct ScheduleFormSheet: View {
    let schedule: StaffSchedule?
    let staff: [Staff]
    let branchId: String
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var selectedUserId = ""
    @State private var scheduleDate = ""
    @State private var shiftStart = ""
    @State private var shiftEnd = ""
    @State private var isDayOff = false
    @State private var notes = ""
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(l10n.details) {
                    if schedule == nil {
                        Picker(l10n.staffMember, selection: $selectedUserId) {
                            Text(l10n.selectStaff).tag("")
                            ForEach(staff) { s in
                                Text(s.nameEn).tag(s.id)
                            }
                        }
                        TextField(l10n.date, text: $scheduleDate)
                    }

                    Toggle(l10n.dayOff, isOn: $isDayOff)
                    if !isDayOff {
                        TextField(l10n.shiftStart, text: $shiftStart)
                        TextField(l10n.shiftEnd, text: $shiftEnd)
                    }
                    TextField(l10n.notes, text: $notes)
                }
            }
            .navigationTitle(schedule == nil ? l10n.addSchedule : l10n.editSchedule)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.save) { Task { await save() } }.disabled(saving)
                }
            }
            .onAppear {
                if let s = schedule {
                    selectedUserId = s.userId; scheduleDate = s.scheduleDate
                    shiftStart = s.shiftStart; shiftEnd = s.shiftEnd
                    isDayOff = s.isDayOff; notes = s.notes ?? ""
                }
            }
        }
    }

    private func save() async {
        saving = true
        if let s = schedule {
            let body = ScheduleUpdate(
                shiftStart: isDayOff ? nil : (shiftStart.isEmpty ? nil : shiftStart),
                shiftEnd: isDayOff ? nil : (shiftEnd.isEmpty ? nil : shiftEnd),
                isDayOff: isDayOff,
                notes: notes.isEmpty ? nil : notes
            )
            _ = try? await api.updateSchedule(s.id, body: body)
        } else {
            let body = ScheduleCreate(
                branchId: branchId,
                userId: selectedUserId,
                scheduleDate: scheduleDate,
                shiftStart: isDayOff ? "00:00" : shiftStart,
                shiftEnd: isDayOff ? "00:00" : shiftEnd,
                isDayOff: isDayOff,
                notes: notes.isEmpty ? nil : notes
            )
            _ = try? await api.createSchedule(body)
        }
        await onSave()
        saving = false
        dismiss()
    }
}
