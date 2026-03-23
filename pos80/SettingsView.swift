// SettingsView.swift — App configuration & staff management
import SwiftUI

private enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.ampos.pos80"
    }
}

struct SettingsView: View {
    @Environment(AppState.self) var appState
    private let l10n = L10n.shared
    @State private var settings: AppSettings?
    @State private var staff: [Staff] = []
    @State private var broadcasts: [BroadcastItem] = []
    @State private var unreadBroadcastCount = 0
    @State private var isLoading = false
    @State private var selectedSection: SettingsSection = .general

    private let api = APIService.shared

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
            Rectangle().fill(AppTheme.border).frame(width: 1)
            settingsContent
        }
        .background(
            LinearGradient(
                colors: [AppTheme.bg, Color(hex: "F6ECE0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        )
        .task { await loadAll() }
    }

    // MARK: - Sidebar
    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CONTROL ROOM")
                    .font(AppTheme.caption(11))
                    .tracking(2)
                    .foregroundColor(AppTheme.accent)
                Text(l10n.settings)
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
                Text(l10n.configurePos)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .padding(.top, 20)

            Rectangle().fill(AppTheme.border).frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            ForEach(SettingsSection.allCases, id: \.self) { section in
                SettingsSidebarRow(
                    section: section,
                    isSelected: selectedSection == section,
                    badgeCount: section == .broadcasts ? unreadBroadcastCount : nil
                ) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedSection = section
                    }
                }
            }

            Spacer()

            // App Version
            VStack(spacing: 4) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
                Text("AMPOS POS v\(AppInfo.version)")
                    .font(AppTheme.caption(11))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 220)
        .background(
            LinearGradient(
                colors: [AppTheme.surface, Color(hex: "F2E6D7")],
                startPoint: .top,
                endPoint: .bottom)
        )
    }

    // MARK: - Content Area
    @ViewBuilder
    private var settingsContent: some View {
        if isLoading {
            ProgressView()
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    switch selectedSection {
                    case .general:   GeneralSettingsSection(settings: $settings)
                    case .broadcasts: BroadcastsSection(broadcasts: $broadcasts, unreadCount: $unreadBroadcastCount)
                    case .receipt:   ReceiptSettingsSection(settings: $settings)
                    case .printer:   PrinterSettingsSection(settings: $settings)
                    case .tax:       TaxSettingsSection(settings: $settings)
                    case .staff:     StaffSettingsSection(staff: $staff)
                    case .about:     AboutSection()
                    }
                }
                .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.bg)
        }
    }

    private func loadAll() async {
        isLoading = true
        async let s = try? api.fetchSettings()
        async let st = try? api.fetchStaff()
        async let br = try? api.fetchBroadcasts()
        let (settingsResult, staffResult, broadcastsResult) = await (s, st, br)
        settings = settingsResult
        staff = staffResult ?? []
        broadcasts = broadcastsResult?.items ?? []
        unreadBroadcastCount = broadcastsResult?.unreadCount ?? 0
        appState.latestBroadcasts = broadcasts
        appState.unreadBroadcastCount = unreadBroadcastCount
        isLoading = false
    }
}

// MARK: - Section enum
enum SettingsSection: String, CaseIterable {
    case general  = "General"
    case broadcasts = "Broadcasts"
    case receipt  = "Receipt"
    case printer  = "Printer"
    case tax      = "Tax & Compliance"
    case staff    = "Staff"
    case about    = "About"

    var localizedName: String {
        let l = L10n.shared
        switch self {
        case .general: return l.general
        case .broadcasts: return l.broadcasts
        case .receipt: return l.receipt
        case .printer: return l.printer
        case .tax:     return l.taxCompliance
        case .staff:   return l.staff
        case .about:   return l.about
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .broadcasts: return "megaphone.fill"
        case .receipt: return "doc.text.fill"
        case .printer: return "printer.fill"
        case .tax:     return "percent"
        case .staff:   return "person.2.fill"
        case .about:   return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return AppTheme.accent
        case .broadcasts: return AppTheme.warning
        case .receipt: return AppTheme.info
        case .printer: return AppTheme.success
        case .tax:     return AppTheme.warning
        case .staff:   return Color(hex: "#EC4899")
        case .about:   return AppTheme.textSecondary
        }
    }
}

// MARK: - Sidebar Row
struct SettingsSidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool
    let badgeCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : section.color)
                    .frame(width: 28, height: 28)
                    .background(isSelected ? section.color : section.color.opacity(0.12))
                    .cornerRadius(8)
                Text(section.localizedName)
                    .font(AppTheme.caption(13))
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                if let badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(AppTheme.caption(10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.warning)
                        .cornerRadius(999)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.accent.opacity(0.08) : Color.clear)
            .cornerRadius(10)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Card
struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String? = nil, icon: String, color: Color, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.12))
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AppTheme.headline()).foregroundColor(AppTheme.textPrimary)
                    if let sub = subtitle {
                        Text(sub).font(AppTheme.caption()).foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, 4)
        }
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r16)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
            .strokeBorder(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.shadow.opacity(0.7), radius: 18, y: 8)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let label: String
    let value: String
    var isEditable: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.caption(13))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.caption(13))
                .foregroundColor(isEditable ? AppTheme.accent : AppTheme.textPrimary)
            if isEditable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            action != nil
                ? Color.white.opacity(0.001) // tappable area
                : Color.clear
        )
        .onTapGesture { action?() }
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border.opacity(0.6)).frame(height: 0.5).padding(.leading, 20)
        }
    }
}

struct SettingsToggleRow: View {
    let label: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTheme.caption(13))
                    .foregroundColor(AppTheme.textSecondary)
                if let sub = subtitle {
                    Text(sub)
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.accent))
                .labelsHidden()
                .scaleEffect(0.85)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border.opacity(0.6)).frame(height: 0.5).padding(.leading, 20)
        }
    }
}

struct BroadcastsSection: View {
    @Binding var broadcasts: [BroadcastItem]
    @Binding var unreadCount: Int
    @Environment(AppState.self) var appState
    private let l10n = L10n.shared
    private let api = APIService.shared
    @State private var dismissingBroadcastId: String?

    var body: some View {
        if broadcasts.isEmpty {
            SettingsCard(title: l10n.broadcastsInbox, subtitle: nil, icon: "megaphone.fill", color: AppTheme.warning) {
                VStack(spacing: 10) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.textMuted)
                    Text(l10n.noBroadcasts)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
        } else {
            SettingsCard(
                title: l10n.broadcastsInbox,
                subtitle: l10n.unreadBroadcasts(unreadCount),
                icon: "megaphone.fill",
                color: AppTheme.warning
            ) {
                ForEach(broadcasts) { item in
                    broadcastRow(item)
                }
            }
        }
    }

    private func broadcastRow(_ item: BroadcastItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(AppTheme.headline(15))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(item.body)
                        .font(AppTheme.body(13))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    Task { await dismiss(item) }
                } label: {
                    if dismissingBroadcastId == item.id {
                        ProgressView()
                            .tint(AppTheme.warning)
                            .scaleEffect(0.75)
                            .frame(width: 44, height: 30)
                    } else {
                        Text(l10n.dismiss)
                            .font(AppTheme.caption(12))
                            .foregroundColor(AppTheme.warning)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.warning.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
                .disabled(dismissingBroadcastId != nil)
            }

            HStack(spacing: 8) {
                if let createdAt = item.createdAt, !createdAt.isEmpty {
                    Label(relativeDateLabel(createdAt), systemImage: "clock")
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textMuted)
                }
                if let plan = item.audiencePlan, !plan.isEmpty {
                    Text(plan.uppercased())
                        .font(AppTheme.caption(10))
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.1))
                        .cornerRadius(999)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border.opacity(0.6)).frame(height: 0.5).padding(.leading, 20)
        }
    }

    private func dismiss(_ item: BroadcastItem) async {
        dismissingBroadcastId = item.id
        do {
            try await api.dismissBroadcast(item.id)
            broadcasts.removeAll { $0.id == item.id }
            unreadCount = broadcasts.count
            appState.latestBroadcasts = broadcasts
            appState.unreadBroadcastCount = unreadCount
            appState.showSuccess(l10n.dismiss)
        } catch {
            appState.showSuccess(error.localizedDescription)
        }
        dismissingBroadcastId = nil
    }

    private func relativeDateLabel(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return value }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - General Settings
struct GeneralSettingsSection: View {
    @Binding var settings: AppSettings?
    @Environment(AppState.self) var appState
    private let l10n = L10n.shared
    @State private var apiURL: String = UserDefaults.standard.string(forKey: "api_base_url") ?? "http://localhost:8000"

    private var apiURLWarning: String? {
        let candidate = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard APIConfig.shouldWarnAboutLoopback(candidate) else { return nil }
        return "localhost works on the simulator only. On a real iPad, set the Mac or backend LAN IP instead."
    }

    var body: some View {
        SettingsCard(title: "Server Connection", subtitle: "API endpoint", icon: "server.rack", color: AppTheme.info) {
            HStack {
                Text("Server URL")
                    .font(AppTheme.caption(13))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 100, alignment: .leading)
                Spacer()
                TextField("http://localhost:8000", text: $apiURL)
                    .font(AppTheme.caption(13))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 300)
                    .onSubmit {
                        UserDefaults.standard.set(apiURL, forKey: "api_base_url")
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppTheme.border.opacity(0.6)).frame(height: 0.5).padding(.leading, 20)
            }

            if let warning = apiURLWarning {
                HStack {
                    Text(warning)
                        .font(AppTheme.caption(12))
                        .foregroundColor(AppTheme.warning)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(AppTheme.border.opacity(0.6)).frame(height: 0.5).padding(.leading, 20)
                }
            }

            HStack {
                Spacer()
                Button {
                    UserDefaults.standard.set(apiURL, forKey: "api_base_url")
                    appState.showSuccess("Server URL saved")
                } label: {
                    Text("Save")
                        .font(AppTheme.caption(13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent)
                        .cornerRadius(8)
                }
                .padding(12)
            }
        }

        SettingsCard(title: l10n.storeInfo, icon: "building.2.fill", color: AppTheme.accent) {
            SettingsRow(label: l10n.businessName, value: "AMPOS")
            SettingsRow(label: l10n.currency, value: settings?.currency ?? "SAR")
            SettingsRow(label: l10n.timeZone, value: settings?.timezone ?? "Asia/Riyadh")
        }

        // Language Toggle
        SettingsCard(title: l10n.languageLabel, icon: "globe", color: AppTheme.accent) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.languageLabel)
                        .font(AppTheme.caption(13))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(L10n.Language.allCases, id: \.self) { lang in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                l10n.language = lang
                            }
                        } label: {
                            Text(lang.displayName)
                                .font(AppTheme.caption(12))
                                .foregroundColor(l10n.language == lang ? .white : AppTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(l10n.language == lang ? AppTheme.accent : AppTheme.cardHover)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }

        SettingsCard(title: l10n.appearance, icon: "paintbrush.pointed.fill", color: Color(hex: "A78BFA")) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.darkMode)
                        .font(AppTheme.caption(13))
                        .foregroundColor(AppTheme.textSecondary)
                    Text(l10n.switchTheme)
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            appState.isDark = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(l10n.light)
                                .font(AppTheme.caption(12))
                        }
                        .foregroundColor(!appState.isDark ? .white : AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(!appState.isDark ? Color(hex: "FBBF24").opacity(0.9) : AppTheme.cardHover)
                        .cornerRadius(8)
                    }
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            appState.isDark = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(l10n.dark)
                                .font(AppTheme.caption(12))
                        }
                        .foregroundColor(appState.isDark ? .white : AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(appState.isDark ? AppTheme.accent : AppTheme.cardHover)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }

        SettingsCard(title: "POS Behavior", icon: "ipad", color: AppTheme.info) {
            SettingsRow(label: "Screen Orientation", value: "Landscape")
            SettingsRow(label: "Idle Timeout", value: "5 minutes")
            SettingsRow(label: "Auto-Print Receipt", value: "Enabled")
        }

        SettingsCard(title: "Security", icon: "lock.shield.fill", color: AppTheme.danger) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face ID Lock")
                        .font(AppTheme.caption(13))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Lock POS when app goes to background")
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.isBiometricEnabled },
                    set: { appState.isBiometricEnabled = $0 }
                ))
                .tint(AppTheme.accent)
                .labelsHidden()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Receipt Settings
struct ReceiptSettingsSection: View {
    @Binding var settings: AppSettings?
    @Environment(AppState.self) var appState
    @State private var footer = ""
    @State private var paperSize = "80mm"
    @State private var fontSize = "normal"
    @State private var autoprint = true
    @State private var showLogo   = true
    @State private var showVAT    = true
    @State private var isSaving = false

    private let api = APIService.shared

    var body: some View {
        SettingsCard(title: "Receipt Options", icon: "doc.text.fill", color: AppTheme.info) {
            SettingsToggleRow(label: "Auto-print on sale", subtitle: "Print receipt after every payment", isOn: $autoprint)
            SettingsToggleRow(
                label: "Sale completion sound",
                subtitle: "Play voice confirmation when payment succeeds",
                isOn: Binding(
                    get: { appState.isSaleCompletionSoundEnabled },
                    set: { appState.isSaleCompletionSoundEnabled = $0 }
                )
            )
            SettingsToggleRow(label: "Show store logo", subtitle: "Include logo in receipt header", isOn: $showLogo)
            SettingsToggleRow(label: "Include VAT breakdown", subtitle: "Show tax details on receipt", isOn: $showVAT)
        }

        SettingsCard(title: "Receipt Format", icon: "doc.richtext.fill", color: AppTheme.accent) {
            HStack {
                Text("Paper Size")
                    .font(AppTheme.caption(13))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Picker("", selection: $paperSize) {
                    Text("58mm").tag("58mm")
                    Text("80mm").tag("80mm")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            HStack {
                Text("Font Size")
                    .font(AppTheme.caption(13))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Picker("", selection: $fontSize) {
                    Text("Small").tag("small")
                    Text("Normal").tag("normal")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }

        SettingsCard(title: "Receipt Footer", icon: "text.alignleft", color: AppTheme.textSecondary) {
            TextField("Footer text...", text: $footer)
                .font(AppTheme.caption(13))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }

        HStack {
            Spacer()
            Button {
                Task { await saveReceiptSettings() }
            } label: {
                HStack(spacing: 6) {
                    if isSaving { ProgressView().tint(.white).scaleEffect(0.7) }
                    Text("Save Receipt Settings")
                }
                .font(AppTheme.caption(13))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(AppTheme.accent)
                .cornerRadius(10)
            }
            .disabled(isSaving)
        }
        .onAppear {
            footer = settings?.receiptFooter ?? "Thank you for your visit!"
            paperSize = settings?.paperSize ?? "80mm"
            fontSize = settings?.receiptFontSize ?? "normal"
        }
    }

    private func saveReceiptSettings() async {
        guard var s = settings else { return }
        isSaving = true
        s.receiptFooter = footer
        s.paperSize = paperSize
        s.receiptFontSize = fontSize
        do {
            settings = try await api.updateSettings(s)
            appState.showSuccess("Receipt settings saved")
        } catch {
            appState.showSuccess("Failed to save: \(error.localizedDescription)")
        }
        isSaving = false
    }
}

// MARK: - Printer Settings
struct PrinterSettingsSection: View {
    @Binding var settings: AppSettings?
    @Environment(AppState.self) var appState
    @State private var receiptIP    = ""
    @State private var receiptPort  = "9100"
    @State private var kitchenIP    = ""
    @State private var kitchenPort  = "9100"
    @State private var isSaving     = false
    @State private var showDiscovery = false

    private let api = APIService.shared

    var body: some View {
        // ── Auto-discovery button ──────────────────────────────────────────
        Button {
            showDiscovery = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discover Printers Automatically")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Scan WiFi network for ESC/POS printers on port 9100")
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.accent.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDiscovery) {
            PrinterDiscoverySheet(
                onSelectReceipt: { ip, port in
                    receiptIP   = ip
                    receiptPort = String(port)
                    showDiscovery = false
                },
                onSelectKitchen: { ip, port in
                    kitchenIP   = ip
                    kitchenPort = String(port)
                    showDiscovery = false
                }
            )
            .presentationDetents([.fraction(0.7), .large])
            .presentationDragIndicator(.visible)
        }

        SettingsCard(title: "Receipt Printer", icon: "printer.fill", color: AppTheme.success) {
            printerField("IP Address", text: $receiptIP, placeholder: "192.168.1.100")
            printerField("Port", text: $receiptPort, placeholder: "9100")
            HStack {
                Spacer()
                Button {
                    Task { await savePrinterSettings() }
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView().tint(.white).scaleEffect(0.7)
                        }
                        Text("Save & Test Print")
                    }
                    .font(AppTheme.caption(13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.success)
                    .cornerRadius(8)
                    .padding()
                }
                .disabled(isSaving)
            }
        }

        SettingsCard(title: "Kitchen Printer", icon: "printer.dotmatrix.fill", color: AppTheme.warning) {
            printerField("IP Address", text: $kitchenIP, placeholder: "192.168.1.101")
            printerField("Port", text: $kitchenPort, placeholder: "9100")
            HStack {
                Spacer()
                Button {
                    Task { await saveKitchenSettings() }
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView().tint(AppTheme.warning).scaleEffect(0.7)
                        }
                        Text("Save")
                    }
                    .font(AppTheme.caption(13))
                    .foregroundColor(AppTheme.warning)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.warning.opacity(0.12))
                    .cornerRadius(8)
                    .padding()
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            receiptIP = settings?.receiptPrinterIp ?? ""
            receiptPort = settings?.receiptPrinterPort.map(String.init) ?? "9100"
            kitchenIP = settings?.kitchenPrinterIp ?? ""
            kitchenPort = settings?.kitchenPrinterPort.map(String.init) ?? "9100"
        }
    }

    private func printerField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.caption(13))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 120, alignment: .leading)
            Spacer()
            TextField(placeholder, text: text)
                .font(AppTheme.caption(13))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border.opacity(0.6)).frame(height: 0.5).padding(.leading, 20)
        }
    }

    private func savePrinterSettings() async {
        guard var s = settings else { return }
        isSaving = true
        s.receiptPrinterIp = receiptIP.isEmpty ? nil : receiptIP
        s.receiptPrinterPort = Int(receiptPort)
        // Cache locally for receipt printing
        UserDefaults.standard.set(receiptIP, forKey: "receipt_printer_ip")
        UserDefaults.standard.set(receiptPort, forKey: "receipt_printer_port")
        do {
            settings = try await api.updateSettings(s)
            // Test print and show real result
            if !receiptIP.isEmpty, let port = UInt16(receiptPort) {
                appState.showSuccess("Connecting to printer \(receiptIP):\(port)…")
                let ok = await ReceiptPrinter.shared.testPrint(ip: receiptIP, port: port)
                if ok {
                    appState.showSuccess("✅ Test print sent successfully!")
                } else {
                    appState.showSuccess("❌ Could not reach printer. Check IP/port (ESC/POS = 9100)")
                }
            } else {
                appState.showSuccess("Printer settings saved")
            }
        } catch {
            appState.showSuccess("Failed to save: \(error.localizedDescription)")
        }
        isSaving = false
    }

    private func saveKitchenSettings() async {
        guard var s = settings else { return }
        isSaving = true
        s.kitchenPrinterIp = kitchenIP.isEmpty ? nil : kitchenIP
        s.kitchenPrinterPort = Int(kitchenPort)
        do {
            settings = try await api.updateSettings(s)
            appState.showSuccess("Kitchen printer saved")
        } catch {
            appState.showSuccess("Failed to save: \(error.localizedDescription)")
        }
        isSaving = false
    }
}

// MARK: - Tax Settings
struct TaxSettingsSection: View {
    @Binding var settings: AppSettings?

    var body: some View {
        SettingsCard(title: "VAT Configuration", icon: "percent", color: AppTheme.warning) {
            SettingsRow(label: "VAT Number", value: settings?.vatNumber ?? "—")
            SettingsRow(label: "VAT Rate", value: "15%")
            SettingsRow(label: "Tax Inclusion", value: "Inclusive")
        }

        SettingsCard(title: "ZATCA Integration", icon: "checkmark.seal.fill", color: AppTheme.success) {
            SettingsRow(label: "Status", value: "Compliant")
            SettingsRow(label: "Environment", value: "Production")
            SettingsRow(label: "Phase", value: "Phase 2 (Integration)")
        }
    }
}

// MARK: - Staff Settings
struct StaffSettingsSection: View {
    @Binding var staff: [Staff]
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Staff Members")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add Staff")
                    }
                    .font(AppTheme.caption(13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentGrad)
                    .cornerRadius(10)
                }
            }
            .padding(.bottom, 12)

            if staff.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 30))
                        .foregroundColor(AppTheme.textMuted)
                    Text("No staff members")
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r16)
            } else {
                VStack(spacing: 0) {
                    ForEach(staff) { member in
                        StaffRow(member: member)
                    }
                }
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r16)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                    .strokeBorder(AppTheme.border, lineWidth: 1))
            }
        }
    }
}

struct StaffRow: View {
    let member: Staff

    var roleColor: Color {
        switch member.role {
        case "manager": return AppTheme.warning
        case "admin":   return AppTheme.danger
        default:        return AppTheme.info
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(member.nameEn.prefix(1)).uppercased())
                    .font(AppTheme.headline(16))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.nameEn)
                    .font(AppTheme.caption(13))
                    .foregroundColor(AppTheme.textPrimary)
                Text(member.email)
                    .font(AppTheme.caption(11))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            Text(member.role.capitalized)
                .font(AppTheme.caption(11))
                .fontWeight(.semibold)
                .foregroundColor(roleColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(roleColor.opacity(0.12))
                .cornerRadius(6)

            Circle()
                .fill(member.isActive == true ? AppTheme.success : AppTheme.textMuted)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border.opacity(0.5)).frame(height: 0.5).padding(.leading, 16)
        }
    }
}

// MARK: - About Section
struct AboutSection: View {
    @Environment(AppState.self) var appState
    private let l10n = L10n.shared

    var body: some View {
        SettingsCard(title: "Application", icon: "info.circle.fill", color: AppTheme.textSecondary) {
            SettingsRow(label: "Version", value: AppInfo.version)
            SettingsRow(label: "Build", value: AppInfo.build)
            SettingsRow(label: "Bundle ID", value: AppInfo.bundleIdentifier)
            SettingsRow(label: "Platform", value: "iPadOS 17+")
            SettingsRow(label: "API Version", value: "v1")
        }

        SettingsCard(title: l10n.lastManagerApprovals, icon: "person.badge.key.fill", color: AppTheme.warning) {
            if appState.managerApprovalLog.isEmpty {
                Text(l10n.noManagerApprovals)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(appState.managerApprovalLog.prefix(8)) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(AppTheme.warning)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.action)
                                .font(AppTheme.caption(13))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("\(l10n.approvedBy): \(entry.managerName)")
                                .font(AppTheme.caption(11))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("\(l10n.approvedAt): \(formattedApprovalDate(entry.approvedAt))")
                                .font(AppTheme.caption(11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AppTheme.border.opacity(0.5)).frame(height: 0.5).padding(.leading, 20)
                    }
                }
            }
        }

        VStack(spacing: 8) {
            Text("AMPOS POS")
                .font(AppTheme.title2(20))
                .foregroundColor(AppTheme.textPrimary)
            Text("A professional point-of-sale solution powered by the Ampos Platform.")
                .font(AppTheme.caption())
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    private func formattedApprovalDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let output = DateFormatter()
        output.dateFormat = "dd MMM yyyy, HH:mm"
        return output.string(from: date)
    }
}
