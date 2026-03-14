// AppTheme.swift — Ramotion-inspired design system
import SwiftUI

// MARK: - Color Palette
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

enum AppTheme {
    // MARK: - Theme Mode (toggled from AppState/Settings)
    static var isDark: Bool = true

    // MARK: Backgrounds
    static var bg:        Color { isDark ? Color(hex: "080B14") : Color(hex: "F5F7FF") }
    static var surface:   Color { isDark ? Color(hex: "0E1120") : Color(hex: "ECEFFE") }
    static var card:      Color { isDark ? Color(hex: "141826") : Color(hex: "FFFFFF") }
    static var cardHover: Color { isDark ? Color(hex: "1A2035") : Color(hex: "F0F2FF") }
    static var border:    Color { isDark ? Color(hex: "222840") : Color(hex: "DDE1F0") }

    // MARK: Accent
    static let accent    = Color(hex: "6366F1")   // Indigo — same in both modes
    static let accent2   = Color(hex: "818CF8")   // Soft indigo
    static let accentGrad = LinearGradient(
        colors: [Color(hex: "6366F1"), Color(hex: "A78BFA")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accentGradH = LinearGradient(
        colors: [Color(hex: "6366F1"), Color(hex: "A78BFA")],
        startPoint: .leading, endPoint: .trailing)

    // MARK: Semantic
    static let success  = Color(hex: "10D9A0")
    static let warning  = Color(hex: "FBBF24")
    static let danger   = Color(hex: "F87171")
    static let info     = Color(hex: "38BDF8")

    // MARK: Text
    static var textPrimary:   Color { isDark ? Color.white          : Color(hex: "0F172A") }
    static var textSecondary: Color { isDark ? Color(hex: "94A3B8") : Color(hex: "475569") }
    static var textMuted:     Color { isDark ? Color(hex: "475569") : Color(hex: "94A3B8") }

    // MARK: Special
    static let cash     = Color(hex: "22D3A5")
    static let card_pay = Color(hex: "818CF8")
    static let mada     = Color(hex: "38BDF8")
    static var apple:   Color { isDark ? Color(hex: "E2E8F0") : Color(hex: "1C1C1E") }

    // MARK: Corner Radii
    static let r4:  CGFloat = 4
    static let r8:  CGFloat = 8
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    static let r24: CGFloat = 24

    // MARK: Fonts (Rounded system font)
    static func display(_ size: CGFloat = 52) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    static func title1(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func title2(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func headline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func mono(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Reusable Card Modifier
struct ThemeCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(AppTheme.border, lineWidth: 1))
    }
}

// MARK: - Glass Card
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(AppTheme.card.opacity(0.85))
            .cornerRadius(cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headline())
            .foregroundColor(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.accentGradH)
            .cornerRadius(AppTheme.r12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Ghost Button Style
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headline())
            .foregroundColor(AppTheme.accent)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.accent.opacity(configuration.isPressed ? 0.15 : 0.08))
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.accent.opacity(0.4), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Danger Button
struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headline())
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.danger.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(AppTheme.r12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Pill Badge
struct PillBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(AppTheme.caption(11))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(100)
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Number Formatter
extension Double {
    var sarFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return (f.string(from: NSNumber(value: self)) ?? "0.00") + " ﷼"
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.06), .clear],
                        startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func themeCard(padding: CGFloat = 16) -> some View { modifier(ThemeCard(padding: padding)) }
    func glassCard(cornerRadius: CGFloat = 16) -> some View { modifier(GlassCard(cornerRadius: cornerRadius)) }
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
