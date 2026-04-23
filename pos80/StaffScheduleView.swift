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
    @State private var showBulkAdd = false
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
            do {
                staff = try await api.fetchStaff()
            } catch {
                staff = []
                appState.showError(error.localizedDescription)
            }
            await load()
        }
        .sheet(isPresented: $showAdd) {
            ScheduleFormSheet(
                schedule: nil,
                staff: staff,
                branchId: appState.currentUser?.branchId ?? "",
                initialDate: selectedDate,
                onSave: { await load() }
            )
        }
        .sheet(isPresented: $showBulkAdd) {
            BulkScheduleFormSheet(
                staff: staff,
                branchId: appState.currentUser?.branchId ?? "",
                initialStartDate: selectedDate,
                onSave: { await load() }
            )
        }
        .sheet(item: $editingSchedule) { s in
            ScheduleFormSheet(
                schedule: s,
                staff: staff,
                branchId: appState.currentUser?.branchId ?? "",
                initialDate: selectedDate,
                onSave: { await load() }
            )
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.staffSchedules).font(AppTheme.title2(22)).foregroundColor(AppTheme.textPrimary)
                Text(l10n.staffSchedulesSubtitle).font(AppTheme.caption(13)).foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { showBulkAdd = true } label: {
                    Label(l10n.bulkSchedule, systemImage: "calendar.badge.clock")
                        .font(AppTheme.caption(13)).foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(AppTheme.surface).cornerRadius(AppTheme.r12)
                }

                Button { showAdd = true } label: {
                    Label(l10n.addSchedule, systemImage: "plus.circle.fill")
                        .font(AppTheme.caption(13)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppTheme.accentGrad).cornerRadius(AppTheme.r12)
                }
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
        defer { isLoading = false }
        let dateStr = dateFormatter.string(from: selectedDate)
        do {
            schedules = try await api.fetchSchedules(dateFrom: dateStr, dateTo: dateStr)
        } catch {
            schedules = []
            appState.showError(error.localizedDescription)
        }
    }

    private func deleteSchedule(_ id: String) async {
        do {
            try await api.deleteSchedule(id)
            await load()
        } catch {
            appState.showError(error.localizedDescription)
        }
    }
}

// MARK: - Schedule Form
struct ScheduleFormSheet: View {
    let schedule: StaffSchedule?
    let staff: [Staff]
    let branchId: String
    let initialDate: Date
    let onSave: () async -> Void
    @EnvironmentObject var appState: AppState
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

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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
                } else {
                    scheduleDate = dateFormatter.string(from: initialDate)
                    if shiftStart.isEmpty { shiftStart = "09:00" }
                    if shiftEnd.isEmpty { shiftEnd = "17:00" }
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }

        guard !branchId.isEmpty else {
            appState.showError(l10n.scheduleBranchRequired)
            return
        }

        if schedule == nil {
            guard !selectedUserId.isEmpty, !scheduleDate.isEmpty else {
                appState.showError(l10n.completeScheduleFields)
                return
            }
        }

        guard isDayOff || (!shiftStart.isEmpty && !shiftEnd.isEmpty) else {
            appState.showError(l10n.completeScheduleFields)
            return
        }

        if let s = schedule {
            let body = ScheduleUpdate(
                shiftStart: isDayOff ? nil : (shiftStart.isEmpty ? nil : shiftStart),
                shiftEnd: isDayOff ? nil : (shiftEnd.isEmpty ? nil : shiftEnd),
                isDayOff: isDayOff,
                notes: notes.isEmpty ? nil : notes
            )
            do {
                _ = try await api.updateSchedule(s.id, body: body)
            } catch {
                appState.showError(error.localizedDescription)
                return
            }
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
            do {
                _ = try await api.createSchedule(body)
            } catch {
                appState.showError(error.localizedDescription)
                return
            }
        }

        await onSave()
        appState.showSuccess(l10n.scheduleSaved)
        dismiss()
    }
}

struct BulkScheduleFormSheet: View {
    let staff: [Staff]
    let branchId: String
    let onSave: () async -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared
    private let calendar = Calendar(identifier: .gregorian)

    @State private var selectedUserId = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var shiftStart = "09:00"
    @State private var shiftEnd = "17:00"
    @State private var isDayOff = false
    @State private var notes = ""
    @State private var selectedWeekdays: Set<Int>
    @State private var saving = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(staff: [Staff], branchId: String, initialStartDate: Date, onSave: @escaping () async -> Void) {
        self.staff = staff
        self.branchId = branchId
        self.onSave = onSave

        let calendar = Calendar(identifier: .gregorian)
        let normalizedStart = calendar.startOfDay(for: initialStartDate)
        let defaultEnd = calendar.date(byAdding: .day, value: 6, to: normalizedStart) ?? normalizedStart
        _startDate = State(initialValue: normalizedStart)
        _endDate = State(initialValue: defaultEnd)
        _selectedWeekdays = State(initialValue: Set(1...7))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(l10n.details) {
                    Picker(l10n.staffMember, selection: $selectedUserId) {
                        Text(l10n.selectStaff).tag("")
                        ForEach(staff) { s in
                            Text(s.nameEn).tag(s.id)
                        }
                    }
                }

                Section(l10n.scheduleRange) {
                    DatePicker(l10n.fromDate, selection: $startDate, displayedComponents: .date)
                    DatePicker(l10n.toDate, selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section(l10n.applyOnDays) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            Button {
                                toggleWeekday(weekday)
                            } label: {
                                Text(weekdayLabel(weekday))
                                    .font(AppTheme.caption(12))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedWeekdays.contains(weekday) ? AppTheme.accent : AppTheme.surface)
                                    .foregroundColor(selectedWeekdays.contains(weekday) ? .white : AppTheme.textPrimary)
                                    .cornerRadius(AppTheme.r12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(l10n.details) {
                    Toggle(l10n.dayOff, isOn: $isDayOff)
                    if !isDayOff {
                        TextField(l10n.shiftStart, text: $shiftStart)
                        TextField(l10n.shiftEnd, text: $shiftEnd)
                    }
                    TextField(l10n.notes, text: $notes)
                }
            }
            .navigationTitle(l10n.bulkSchedule)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.save) { Task { await save() } }
                        .disabled(saving)
                }
            }
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: l10n.isArabic ? "ar" : "en_US_POSIX")
        return formatter.shortWeekdaySymbols[weekday - 1]
    }

    private func generatedEntries() -> [ScheduleCreate] {
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        var currentDate = normalizedStart
        var entries: [ScheduleCreate] = []

        while currentDate <= normalizedEnd {
            let weekday = calendar.component(.weekday, from: currentDate)
            if selectedWeekdays.contains(weekday) {
                entries.append(
                    ScheduleCreate(
                        branchId: branchId,
                        userId: selectedUserId,
                        scheduleDate: dateFormatter.string(from: currentDate),
                        shiftStart: isDayOff ? "00:00" : shiftStart,
                        shiftEnd: isDayOff ? "00:00" : shiftEnd,
                        isDayOff: isDayOff,
                        notes: notes.isEmpty ? nil : notes
                    )
                )
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return entries
    }

    private func save() async {
        saving = true
        defer { saving = false }

        guard !branchId.isEmpty else {
            appState.showError(l10n.scheduleBranchRequired)
            return
        }

        guard !selectedUserId.isEmpty else {
            appState.showError(l10n.completeScheduleFields)
            return
        }

        guard endDate >= startDate else {
            appState.showError(l10n.invalidScheduleRange)
            return
        }

        guard !selectedWeekdays.isEmpty else {
            appState.showError(l10n.selectAtLeastOneScheduleDay)
            return
        }

        guard isDayOff || (!shiftStart.isEmpty && !shiftEnd.isEmpty) else {
            appState.showError(l10n.completeScheduleFields)
            return
        }

        let entries = generatedEntries()
        guard !entries.isEmpty else {
            appState.showError(l10n.noMatchingScheduleDates)
            return
        }

        do {
            let createdSchedules = try await api.createSchedules(entries)
            await onSave()
            appState.showSuccess(l10n.bulkSchedulesCreated(createdSchedules.count))
            dismiss()
        } catch {
            appState.showError(error.localizedDescription)
        }
    }
}
