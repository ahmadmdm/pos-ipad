// LoginView.swift — Premium Ramotion-style login screen
import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) var appState
    private let l10n = L10n.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var loginMode: LoginMode = .password
    @State private var pinDigits = ["", "", "", ""]
    @State private var focusedPin = 0
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var formOpacity: Double = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var showServerConfig = false
    @State private var serverURLDraft: String = UserDefaults.standard.string(forKey: "api_base_url") ?? "http://localhost:8000"

    enum LoginMode { case password, pin }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [AppTheme.bg, Color(hex: "0E0F1A"), Color(hex: "080B14")],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

                // Decorative blobs
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 500, height: 500)
                        .blur(radius: 80)
                        .offset(x: -200, y: -120)

                    Circle()
                        .fill(Color(hex: "A78BFA").opacity(0.08))
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(x: 200, y: 300)
                }
                .ignoresSafeArea()

                HStack(spacing: 0) {
                    // Left branding panel
                    brandingPanel(geo: geo)

                    // Right login panel
                    loginPanel(geo: geo)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                formOpacity = 1
            }
        }
    }

    // MARK: - Branding Panel
    @ViewBuilder
    private func brandingPanel(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                // Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(AppTheme.accentGrad)
                        .frame(width: 88, height: 88)
                        .shadow(color: AppTheme.accent.opacity(0.6), radius: 24, y: 8)

                    Image(systemName: "storefront.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 8) {
                    Text("ampos")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Color(hex: "C4B5FD")],
                                           startPoint: .leading, endPoint: .trailing))

                    Text(l10n.professionalPOS)
                        .font(AppTheme.body(16))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .opacity(logoOpacity)

                // Feature badges
                VStack(spacing: 12) {
                    ForEach(features.indices, id: \.self) { i in
                        let feature = features[i]
                        HStack(spacing: 12) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 28, height: 28)
                                .background(AppTheme.accent.opacity(0.12))
                                .cornerRadius(8)
                            Text(feature.label)
                                .font(AppTheme.body(14))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 16)
                .opacity(logoOpacity)
            }
            .padding(48)
            Spacer()

            Text(l10n.poweredBy)
                .font(AppTheme.caption())
                .foregroundColor(AppTheme.textMuted)
                .padding(.bottom, 32)
        }
        .frame(width: geo.size.width * 0.42)
    }

    // MARK: - Login Panel
    @ViewBuilder
    private func loginPanel(geo: GeometryProxy) -> some View {
        ZStack {
            // Panel background
            Rectangle()
                .fill(AppTheme.surface)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1)
                }

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 6) {
                        Text(l10n.welcomeBack)
                            .font(AppTheme.title1())
                            .foregroundColor(AppTheme.textPrimary)
                        Text(l10n.signInSubtitle)
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textSecondary)
                    }

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
                .frame(maxWidth: 380)
                Spacer()

                // Server config button
                Button {
                    serverURLDraft = UserDefaults.standard.string(forKey: "api_base_url") ?? "http://localhost:8000"
                    showServerConfig = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 12))
                        Text(UserDefaults.standard.string(forKey: "api_base_url") ?? "http://localhost:8000")
                            .font(AppTheme.caption())
                            .lineLimit(1)
                    }
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.card.opacity(0.6))
                    .cornerRadius(8)
                }
                .padding(.bottom, 24)
            }
            .opacity(formOpacity)
        }
        .frame(width: geo.size.width * 0.58)
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
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r12)
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
            .disabled(email.isEmpty || password.isEmpty || appState.isLoading)
        }
    }

    // MARK: - PIN Form
    private var pinForm: some View {
        VStack(spacing: 20) {
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
            .disabled(email.isEmpty || pinDigits.joined().count < 4 || appState.isLoading)
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
    }
}

// MARK: - Server Config Sheet
struct ServerConfigSheet: View {
    @Binding var urlDraft: String
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Server URL", systemImage: "server.rack")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)

                    TextField("http://192.168.x.x:8000", text: $urlDraft)
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

                    Text("Enter the IP address of the machine running the backend. Example: http://192.168.1.100:8000")
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
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
                        let url = urlDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserDefaults.standard.set(url, forKey: "api_base_url")
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(urlDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
