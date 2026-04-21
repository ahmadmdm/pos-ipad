// LoginView.swift — Premium Ramotion-style login screen
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    private let l10n = L10n.shared
    private let api = APIService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var loginMode: LoginMode = .password
    @State private var pinDigits = ["", "", "", ""]
    @State private var focusedPin = 0
    @State private var pinUsers: [POSUserPreview] = []
    @State private var isLoadingPINUsers = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var formOpacity: Double = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var showServerConfig = false
    @State private var serverURLDraft: String = APIConfig.baseURL
    @State private var tenantCode = APIService.shared.tenantCode ?? ""
    @State private var resolvedTenant = APIService.shared.resolvedTenant
    @State private var isResolvingTenant = false

    private var serverURLWarning: String? {
        let candidate = serverURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard APIConfig.shouldWarnAboutLoopback(candidate) else { return nil }
        return "On a physical iPad, localhost points to the iPad itself. Use your Mac or server LAN IP instead, for example http://192.168.1.100:8000"
    }

    enum LoginMode { case password, pin }

    private var normalizedTenantCode: String {
        tenantCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var isTenantReady: Bool {
        guard let resolvedTenant else { return false }
        return !normalizedTenantCode.isEmpty
            && normalizedTenantCode == (api.tenantCode ?? "").uppercased()
            && api.tenantSlug == resolvedTenant.tenantSlug
    }

    private func usesWideLayout(_ geo: GeometryProxy) -> Bool {
        geo.size.width > 1000
    }

    private func usesCompactHeight(_ geo: GeometryProxy) -> Bool {
        geo.size.height < 900
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                AppTheme.bgGradient
                .ignoresSafeArea()

                // Decorative blobs
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(AppTheme.isDark ? 0.06 : 0.14))
                        .frame(width: 540, height: 540)
                        .blur(radius: 80)
                        .offset(x: -200, y: -120)

                    Circle()
                        .fill(AppTheme.accent2.opacity(AppTheme.isDark ? 0.04 : 0.16))
                        .frame(width: 420, height: 420)
                        .blur(radius: 80)
                        .offset(x: 200, y: 300)

                    Circle()
                        .fill(AppTheme.success.opacity(AppTheme.isDark ? 0.03 : 0.12))
                        .frame(width: 320, height: 320)
                        .blur(radius: 70)
                        .offset(x: 280, y: -180)
                }
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if usesWideLayout(geo) {
                            HStack(spacing: 0) {
                                brandingPanel(geo: geo, compactHeight: usesCompactHeight(geo), wideLayout: true)
                                loginPanel(geo: geo, compactHeight: usesCompactHeight(geo), wideLayout: true)
                            }
                        } else {
                            VStack(spacing: 20) {
                                brandingPanel(geo: geo, compactHeight: true, wideLayout: false)
                                loginPanel(geo: geo, compactHeight: false, wideLayout: false)
                            }
                            .padding(.vertical, 20)
                        }
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .onAppear {
            resolvedTenant = api.resolvedTenant
            tenantCode = api.tenantCode ?? tenantCode
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                formOpacity = 1
            }
            if loginMode == .pin, isTenantReady {
                Task { await loadPINUsers() }
            }
        }
        .onChange(of: loginMode) { newMode in
            guard newMode == .pin, isTenantReady else { return }
            Task { await loadPINUsers() }
        }
        .onChange(of: tenantCode) { newValue in
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if normalized != (api.tenantCode ?? "").uppercased() {
                resolvedTenant = nil
                pinUsers = []
            }
        }
        .sheet(isPresented: $appState.show2FAPrompt) {
            TwoFALoginSheet()
                .environmentObject(appState)
        }
    }

    // MARK: - Branding Panel
    @ViewBuilder
    private func brandingPanel(geo: GeometryProxy, compactHeight: Bool, wideLayout: Bool) -> some View {
        VStack(spacing: 0) {
            if wideLayout {
                Spacer(minLength: compactHeight ? 16 : 24)
            }
            VStack(alignment: .leading, spacing: 24) {
                Text("SERVICE OS")
                    .font(AppTheme.caption(11))
                    .tracking(2)
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(999)

                HStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(AppTheme.accentGrad)
                            .frame(width: 88, height: 88)
                            .shadow(color: AppTheme.accent.opacity(0.34), radius: 24, y: 8)

                        Image(systemName: "storefront.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ampos")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [AppTheme.textPrimary, AppTheme.accent],
                                               startPoint: .leading, endPoint: .trailing))

                        Text(l10n.professionalPOS)
                            .font(AppTheme.body(16))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .opacity(logoOpacity)
                }

                VStack(spacing: 12) {
                    ForEach(features.indices, id: \.self) { i in
                        let feature = features[i]
                        HStack(spacing: 12) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.accent.opacity(0.12))
                                .cornerRadius(10)
                            Text(feature.label)
                                .font(AppTheme.body(14))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppTheme.bg.opacity(0.72))
                        .cornerRadius(AppTheme.r16)
                    }
                }
                .opacity(logoOpacity)
            }
            .padding(compactHeight ? 28 : 40)
            .background(
                RoundedRectangle(cornerRadius: 36)
                    .fill(LinearGradient(
                        colors: AppTheme.isDark
                            ? [AppTheme.card, AppTheme.surfaceElevated]
                            : [AppTheme.card, Color(hex: "F3E2CD")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 36)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 30, y: 14)
            .padding(.horizontal, wideLayout ? (compactHeight ? 20 : 36) : 20)

            if wideLayout {
                Spacer(minLength: compactHeight ? 16 : 24)

                Text(l10n.poweredBy)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.bottom, compactHeight ? 16 : 32)
            }
        }
        .frame(maxWidth: wideLayout ? min(geo.size.width * 0.44, 560) : min(geo.size.width - 40, 760))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Login Panel
    @ViewBuilder
    private func loginPanel(geo: GeometryProxy, compactHeight: Bool, wideLayout: Bool) -> some View {
        ZStack {
            // Panel background
            AppTheme.sidebarGradient
                .overlay(alignment: wideLayout ? .leading : .top) {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: wideLayout ? 1 : nil, height: wideLayout ? nil : 1)
                }

            VStack(spacing: 0) {
                Spacer(minLength: compactHeight ? 20 : 32)
                VStack(spacing: compactHeight ? 24 : 32) {
                    // Header
                    VStack(spacing: 6) {
                        Text(l10n.welcomeBack)
                            .font(AppTheme.title1())
                            .foregroundColor(AppTheme.textPrimary)
                        Text(l10n.signInSubtitle)
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    tenantCodeSection

                    // Mode toggle
                    modePicker

                    // Form
                    if loginMode == .password {
                        passwordForm
                    } else {
                        pinForm
                    }

                    // Error
                    if let err = appState.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.danger)
                                .font(.system(size: 14))
                            Text(err)
                                .font(AppTheme.body(14))
                                .foregroundColor(AppTheme.danger)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.danger.opacity(0.1))
                        .cornerRadius(AppTheme.r12)
                        .offset(x: shakeOffset)
                    }
                }
                .frame(maxWidth: compactHeight ? 420 : 380)
                .padding(compactHeight ? 24 : 32)
                .background(AppTheme.card.opacity(0.92))
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                )
                .shadow(color: AppTheme.shadow, radius: 24, y: 10)
                .padding(.horizontal, 20)
                Spacer(minLength: compactHeight ? 16 : 24)

                // Server config button
                VStack(spacing: 0) {
                    Button {
                        serverURLDraft = APIConfig.baseURL
                        showServerConfig = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 12))
                            Text(APIConfig.baseURL)
                                .font(AppTheme.caption())
                                .lineLimit(1)
                        }
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.card)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(AppTheme.border, lineWidth: 1)
                        )
                    }

                    if APIConfig.shouldWarnAboutLoopbackBaseURL {
                        Text("Backend is set to localhost. This only works on the simulator; set the Mac or server LAN IP for a real iPad.")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.warning)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, compactHeight ? 16 : 24)
            }
            .opacity(formOpacity)
        }
        .frame(maxWidth: wideLayout ? min(geo.size.width * 0.56, 720) : .infinity)
        .frame(minHeight: wideLayout ? geo.size.height : nil)
        .sheet(isPresented: $showServerConfig) {
            ServerConfigSheet(urlDraft: $serverURLDraft)
        }
    }

    // MARK: - Mode Picker
    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach([LoginMode.password, LoginMode.pin], id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        loginMode = mode
                        appState.errorMessage = nil
                    }
                } label: {
                    Text(mode == .password ? l10n.passwordTab : l10n.pinTab)
                        .font(AppTheme.headline(15))
                        .foregroundColor(loginMode == mode ? .white : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(loginMode == mode ? AppTheme.accent : Color.clear)
                        .cornerRadius(AppTheme.r8)
                }
            }
        }
        .padding(4)
        .background(AppTheme.bg)
        .cornerRadius(AppTheme.r12)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Password Form
    private var passwordForm: some View {
        VStack(spacing: 16) {
            // Email
            ThemeTextField(
                icon: "envelope.fill",
                placeholder: l10n.emailPlaceholder,
                text: $email,
                keyboardType: .emailAddress,
                autocapitalization: .never)

            // Password
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 20)
                if showPassword {
                    TextField(l10n.password, text: $password)
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(l10n.password, text: $password)
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.textPrimary)
                }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(AppTheme.textMuted)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.border, lineWidth: 1))

            // Submit
            Button {
                Task {
                    guard await ensureTenantResolved() else {
                        triggerShake()
                        return
                    }
                    await appState.login(email: email, password: password)
                    if appState.errorMessage != nil { triggerShake() }
                }
            } label: {
                ZStack {
                    if appState.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(l10n.signIn)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
            .disabled(email.isEmpty || password.isEmpty || appState.isLoading || isResolvingTenant)
        }
    }

    // MARK: - PIN Form
    private var pinForm: some View {
        VStack(spacing: 20) {
            pinUsersSection

            ThemeTextField(
                icon: "envelope.fill",
                placeholder: l10n.emailPlaceholder,
                text: $email,
                keyboardType: .emailAddress,
                autocapitalization: .never)

            // PIN display
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.card)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(focusedPin == i ? AppTheme.accent : AppTheme.border,
                                              lineWidth: focusedPin == i ? 2 : 1))
                            .frame(width: 64, height: 72)

                        if pinDigits[i].isEmpty {
                            Circle()
                                .fill(AppTheme.textMuted.opacity(0.3))
                                .frame(width: 10, height: 10)
                        } else {
                            Circle()
                                .fill(AppTheme.accent)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .animation(.spring(response: 0.2), value: pinDigits[i])
                }
            }

            // Numpad
            numpad

            Button {
                Task {
                    guard await ensureTenantResolved() else {
                        triggerShake()
                        return
                    }
                    let pin = pinDigits.joined()
                    await appState.loginWithPIN(email: email, pin: pin)
                    if appState.errorMessage != nil {
                        pinDigits = ["", "", "", ""]
                        focusedPin = 0
                        triggerShake()
                    }
                }
            } label: {
                ZStack {
                    if appState.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(l10n.signInWithPIN)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
            .disabled(email.isEmpty || pinDigits.joined().count < 4 || appState.isLoading || isResolvingTenant)
        }
    }

    private var tenantCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.tenantCode)
                .font(AppTheme.caption())
                .foregroundColor(AppTheme.textMuted)

            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.crop.circle")
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 20)
                    TextField(l10n.tenantCodePlaceholder, text: $tenantCode)
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .submitLabel(.done)
                        .onSubmit {
                            Task { _ = await resolveTenantCode() }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r12)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                    .strokeBorder(AppTheme.border, lineWidth: 1))

                Button {
                    Task { _ = await resolveTenantCode() }
                } label: {
                    ZStack {
                        if isResolvingTenant {
                            ProgressView().tint(.white)
                        } else {
                            Text(l10n.resolveTenant)
                        }
                    }
                    .frame(minWidth: 92)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(normalizedTenantCode.isEmpty || isResolvingTenant || (isTenantReady && normalizedTenantCode == (api.tenantCode ?? "").uppercased()))
            }

            if let resolvedTenant {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppTheme.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.tenantResolved)
                            .font(AppTheme.caption(11))
                            .foregroundColor(AppTheme.success)
                        Text(l10n.isArabic ? resolvedTenant.tenantNameAr : resolvedTenant.tenantName)
                            .font(AppTheme.headline(14))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.success.opacity(0.08))
                .cornerRadius(AppTheme.r12)
            } else {
                Text(l10n.enterTenantCodeFirst)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
        }
    }

    // MARK: - Numpad
    private var numpad: some View {
        VStack(spacing: 10) {
            ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { num in
                        NumButton(label: "\(num)") { addPinDigit("\(num)") }
                    }
                }
            }
            HStack(spacing: 10) {
                NumButton(label: "⌫", isDestructive: true) { removePinDigit() }
                NumButton(label: "0") { addPinDigit("0") }
                NumButton(label: "✓", accent: true) {
                    Task {
                        guard await ensureTenantResolved() else {
                            triggerShake()
                            return
                        }
                        let pin = pinDigits.joined()
                        guard pin.count == 4 else { return }
                        await appState.loginWithPIN(email: email, pin: pin)
                        if appState.errorMessage != nil {
                            pinDigits = ["", "", "", ""]
                            focusedPin = 0
                            triggerShake()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pinUsersSection: some View {
        if isLoadingPINUsers {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(AppTheme.accent)
                Text(l10n.loadingCashiers)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
            }
        } else if !pinUsers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(l10n.quickCashierAccess)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(pinUsers) { user in
                            Button {
                                email = user.email
                                appState.errorMessage = nil
                                pinDigits = ["", "", "", ""]
                                focusedPin = 0
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName)
                                        .font(AppTheme.headline(13))
                                        .foregroundColor(email == user.email ? .white : AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(user.role.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(AppTheme.caption(11))
                                        .foregroundColor(email == user.email ? .white.opacity(0.8) : AppTheme.textMuted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(email == user.email ? AppTheme.accent : AppTheme.card)
                                .cornerRadius(AppTheme.r12)
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                    .strokeBorder(email == user.email ? AppTheme.accent : AppTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func addPinDigit(_ d: String) {
        guard focusedPin < 4 else { return }
        pinDigits[focusedPin] = d
        if focusedPin < 3 { focusedPin += 1 }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removePinDigit() {
        if !pinDigits[focusedPin].isEmpty {
            pinDigits[focusedPin] = ""
        } else if focusedPin > 0 {
            focusedPin -= 1
            pinDigits[focusedPin] = ""
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.08, dampingFraction: 0.3).repeatCount(4, autoreverses: true)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeOffset = 0 }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func loadPINUsers() async {
        guard isTenantReady else {
            pinUsers = []
            return
        }
        isLoadingPINUsers = true
        defer { isLoadingPINUsers = false }
        do {
            pinUsers = try await api.fetchPOSUsers()
        } catch {
            pinUsers = []
        }
    }

    private func ensureTenantResolved() async -> Bool {
        guard !isTenantReady else { return true }
        return await resolveTenantCode()
    }

    private func resolveTenantCode() async -> Bool {
        let code = normalizedTenantCode
        guard !code.isEmpty else {
            appState.errorMessage = l10n.enterTenantCodeFirst
            return false
        }

        isResolvingTenant = true
        appState.errorMessage = nil
        defer { isResolvingTenant = false }

        do {
            let resolved = try await api.resolveTenantCode(code)
            resolvedTenant = resolved
            if loginMode == .pin {
                await loadPINUsers()
            }
            return true
        } catch {
            resolvedTenant = nil
            pinUsers = []
            appState.errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: Features list
    private var features: [(icon: String, label: String)] {
        [
            (icon: "cart.fill", label: l10n.fastOrderMgmt),
            (icon: "chart.bar.fill", label: l10n.realTimeAnalytics),
            (icon: "printer.fill", label: l10n.escPrinting),
            (icon: "lock.shield.fill", label: l10n.zatcaCompliant)
        ]
    }
}

// MARK: - NumButton
private struct NumButton: View {
    let label: String
    var isDestructive = false
    var accent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(isDestructive ? AppTheme.danger : accent ? .white : AppTheme.textPrimary)
                .frame(width: 72, height: 52)
                .background(accent ? AppTheme.accent :
                            isDestructive ? AppTheme.danger.opacity(0.12) : AppTheme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isDestructive ? AppTheme.danger.opacity(0.3) :
                                  accent ? .clear : AppTheme.border, lineWidth: 1))
                .shadow(color: accent ? AppTheme.accent.opacity(0.2) : .clear, radius: 10, y: 4)
        }
    }
}

// MARK: - ThemeTextField (reusable)
struct ThemeTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textPrimary)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(autocapitalization)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r12)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
            .strokeBorder(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.shadow.opacity(0.5), radius: 10, y: 4)
    }
}

// MARK: - Server Config Sheet
struct ServerConfigSheet: View {
    @Binding var urlDraft: String
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    var body: some View {
        CompatNavigationContainer {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Server URL", systemImage: "server.rack")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)

                    TextField(APIConfig.defaultBaseURL, text: $urlDraft)
                        .font(AppTheme.body())
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppTheme.card)
                        .cornerRadius(AppTheme.r12)
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                            .strokeBorder(AppTheme.border, lineWidth: 1))

                    Text("Default endpoint: \(APIConfig.defaultBaseURL). You can replace it with another backend URL if needed.")
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)

                    if APIConfig.shouldWarnAboutLoopback(urlDraft.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        Text("localhost and 127.0.0.1 point to the iPad itself. For a real device, enter the LAN IP of the Mac or backend server.")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.warning)
                    }
                }

                if saved {
                    Label("Saved!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                        .font(AppTheme.headline())
                }

                Spacer()
            }
            .padding(24)
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle("Server Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        APIConfig.persistBaseURL(urlDraft)
                        urlDraft = APIConfig.baseURL
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .disabled(urlDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .compatMediumDetent()
    }
}

// MARK: - 2FA Login Sheet
struct TwoFALoginSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    private let l10n = L10n.shared
    @State private var totpCode = ""

    var body: some View {
        CompatNavigationContainer {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.accent)

                Text(l10n.twoFARequired)
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)

                Text(l10n.enterTOTPCode)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                TextField(l10n.totpCode, text: $totpCode)
                    .font(AppTheme.title2(28))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.card)
                    .cornerRadius(AppTheme.r12)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                        .strokeBorder(AppTheme.accent.opacity(0.4), lineWidth: 1))
                    .frame(maxWidth: 200)

                if let err = appState.errorMessage {
                    Text(err)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.danger)
                }

                Button {
                    Task { await appState.validate2FA(code: totpCode) }
                } label: {
                    ZStack {
                        if appState.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(l10n.verify)
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                .disabled(totpCode.count < 6 || appState.isLoading)
                .frame(maxWidth: 300)

                Spacer()
            }
            .padding(32)
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle(l10n.twoFactorAuth)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.cancel) {
                        appState.pending2FAToken = nil
                        appState.show2FAPrompt = false
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
