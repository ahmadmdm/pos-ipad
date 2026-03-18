// SettingsView.swift — App configuration & staff management
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var settings: AppSettings?
    @State private var staff: [Staff] = []
    @State private var isLoading = false
    @State private var selectedSection: SettingsSection = .general

    private let api = APIService.shared

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
            Rectangle().fill(AppTheme.border).frame(width: 1)
            settingsContent
        }
        .background(AppTheme.bg)
        .task { await loadAll() }
    }

    // MARK: - Sidebar
    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
                Text("Configure your POS")
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
                SettingsSidebarRow(section: section, isSelected: selectedSection == section) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedSection = section
                    }
                }
            }

            Spacer()

            // App Version
            VStack(spacing: 4) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
                Text("AMPOS POS v1.0.0")
                    .font(AppTheme.caption(11))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 220)
        .background(AppTheme.surface)
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
        let (settingsResult, staffResult) = await (s, st)
        settings = settingsResult
        staff = staffResult ?? []
        isLoading = false
    }
}

// MARK: - Section enum
enum SettingsSection: String, CaseIterable {
    case general  = "General"
    case receipt  = "Receipt"
    case printer  = "Printer"
    case tax      = "Tax & Compliance"
    case staff    = "Staff"
    case about    = "About"

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
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
                Text(section.rawValue)
                    .font(AppTheme.caption(13))
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
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

// MARK: - General Settings
struct GeneralSettingsSection: View {
    @Binding var settings: AppSettings?
    @EnvironmentObject private var appState: AppState
    @State private var apiURL: String = UserDefaults.standard.string(forKey: "api_base_url") ?? "http://localhost:8000"

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

        SettingsCard(title: "Store Info", icon: "building.2.fill", color: AppTheme.accent) {
            SettingsRow(label: "Business Name", value: "AMPOS")
            SettingsRow(label: "Currency", value: settings?.currency ?? "SAR")
            SettingsRow(label: "Time Zone", value: settings?.timezone ?? "Asia/Riyadh")
            SettingsRow(label: "Language", value: "English / العربية")
        }

        SettingsCard(title: "Appearance", icon: "paintbrush.pointed.fill", color: Color(hex: "A78BFA")) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dark Mode")
                        .font(AppTheme.caption(13))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Switch between light and dark theme")
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
                            Text("Light")
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
                            Text("Dark")
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
    }
}

// MARK: - Receipt Settings
struct ReceiptSettingsSection: View {
    @Binding var settings: AppSettings?
    @EnvironmentObject private var appState: AppState
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
    @EnvironmentObject private var appState: AppState
    @State private var receiptIP    = ""
    @State private var receiptPort  = "9100"
    @State private var kitchenIP    = ""
    @State private var kitchenPort  = "9100"
    @State private var isSaving = false

    private let api = APIService.shared

    var body: some View {
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
    var body: some View {
        SettingsCard(title: "Application", icon: "info.circle.fill", color: AppTheme.textSecondary) {
            SettingsRow(label: "Version", value: "1.0.0")
            SettingsRow(label: "Build", value: "100")
            SettingsRow(label: "Bundle ID", value: "com.ampos.pos80")
            SettingsRow(label: "Platform", value: "iPadOS 17+")
            SettingsRow(label: "API Version", value: "v1")
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
}
