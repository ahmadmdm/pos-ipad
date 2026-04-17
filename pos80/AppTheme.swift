// AppTheme.swift — Ramotion-grade design system (Dark Elegant + Warm Light)
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AppTheme
// ─────────────────────────────────────────────────────────────────────────────
enum AppTheme {
    // MARK: - Theme Mode (toggled from AppState/Settings)
    static var isDark: Bool = false

    // ── Dark palette ────────────────────────────────────────────────────────
    // Layered depth system:  bg → surface → card → cardHover
    // Each level is ~3-4% lighter, giving perceptible elevation without harshness.
    // A subtle warm undertone (hue ≈ 225-230°) prevents the "dead screen" look.

    // MARK: Backgrounds
    static var bg:             Color { isDark ? Color(hex: "08090E")  : Color(hex: "F4ECE1") }
    static var surface:        Color { isDark ? Color(hex: "0F1117")  : Color(hex: "FBF6EE") }
    static var surfaceElevated:Color { isDark ? Color(hex: "15171F")  : Color(hex: "F7F0E5") }
    static var card:           Color { isDark ? Color(hex: "1A1D27")  : Color(hex: "FFFDFC") }
    static var cardHover:      Color { isDark ? Color(hex: "22252F")  : Color(hex: "F2E6D6") }
    static var border:         Color { isDark ? Color.white.opacity(0.06) : Color(hex: "E8D9C6") }
    static var borderSubtle:   Color { isDark ? Color.white.opacity(0.03) : Color(hex: "F0E4D4") }
    static var shadow:         Color { isDark ? Color(hex: "C96E43").opacity(0.08) : Color(hex: "8B6B4A").opacity(0.14) }
    static var shadowHeavy:    Color { isDark ? Color.black.opacity(0.45) : Color(hex: "8B6B4A").opacity(0.22) }

    // MARK: Overlay & Frosted
    static var overlayThin:    Color { isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02) }
    static var overlayMedium:  Color { isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04) }

    // MARK: Accent — warm copper / gold
    static let accent    = Color(hex: "D4845A")
    static let accent2   = Color(hex: "E8B078")
    static var accentMuted: Color { isDark ? Color(hex: "D4845A").opacity(0.15) : Color(hex: "D4845A").opacity(0.10) }
    static let accentGrad = LinearGradient(
        colors: [Color(hex: "C06A3C"), Color(hex: "E4A35A")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accentGradH = LinearGradient(
        colors: [Color(hex: "C06A3C"), Color(hex: "E4A35A")],
        startPoint: .leading, endPoint: .trailing)

    // MARK: Dark-mode ambient gradients
    static var bgGradient: LinearGradient {
        isDark
        ? LinearGradient(colors: [Color(hex: "08090E"), Color(hex: "0C0E16"), Color(hex: "08090E")],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
        : LinearGradient(colors: [Color(hex: "F4ECE1"), Color(hex: "FBF5EC"), Color(hex: "EFDCC7")],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var sidebarGradient: LinearGradient {
        isDark
        ? LinearGradient(colors: [Color(hex: "0B0D14"), Color(hex: "0F1118")],
                         startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color(hex: "F7F0E5"), Color(hex: "F0E5D6")],
                         startPoint: .top, endPoint: .bottom)
    }

    // MARK: Glow (dark-mode halo for accent elements)
    static var glow: Color { isDark ? accent.opacity(0.25) : accent.opacity(0.0) }

    // MARK: Semantic
    static var success: Color { isDark ? Color(hex: "34D399") : Color(hex: "1E9B72") }
    static var warning: Color { isDark ? Color(hex: "FBBF24") : Color(hex: "D4932D") }
    static var danger:  Color { isDark ? Color(hex: "F87171") : Color(hex: "D45B4B") }
    static var info:    Color { isDark ? Color(hex: "60A5FA") : Color(hex: "3E7EA5") }

    // MARK: Text — improved contrast for dark mode
    static var textPrimary:   Color { isDark ? Color(hex: "F1F0EE")  : Color(hex: "2A201A") }
    static var textSecondary: Color { isDark ? Color(hex: "9CA3AF")  : Color(hex: "6A584A") }
    static var textMuted:     Color { isDark ? Color(hex: "5C6370")  : Color(hex: "A49383") }
    static var textOnAccent:  Color { Color.white }

    // MARK: Special — payment method colors
    static var cash:     Color { isDark ? Color(hex: "34D399") : Color(hex: "2CA07A") }
    static var card_pay: Color { isDark ? Color(hex: "60A5FA") : Color(hex: "5A7EC2") }
    static var mada:     Color { isDark ? Color(hex: "67E8F9") : Color(hex: "3A97A7") }
    static var apple:    Color { isDark ? Color(hex: "F1F0EE") : Color(hex: "1C1C1E") }

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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Reusable Card Modifier (elevated dark-mode card)
// ─────────────────────────────────────────────────────────────────────────────
struct ThemeCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r16)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.r16)
                    .strokeBorder(AppTheme.border, lineWidth: AppTheme.isDark ? 1 : 1)
            )
            .shadow(color: AppTheme.shadow, radius: AppTheme.isDark ? 24 : 18, y: AppTheme.isDark ? 4 : 8)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Glass Card (frosted glass effect)
// ─────────────────────────────────────────────────────────────────────────────
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background {
                if AppTheme.isDark {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.card.opacity(0.75))
                        .background(.ultraThinMaterial.opacity(0.5))
                        .cornerRadius(cornerRadius)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.card.opacity(0.72))
                        .background(.ultraThinMaterial)
                        .cornerRadius(cornerRadius)
                }
            }
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        AppTheme.isDark
                            ? Color.white.opacity(0.06)
                            : AppTheme.border.opacity(0.7),
                        lineWidth: 1
                    )
            )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Primary Button Style (with dark-mode glow)
// ─────────────────────────────────────────────────────────────────────────────
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
            .shadow(color: AppTheme.isDark ? AppTheme.glow : AppTheme.accent.opacity(0.22),
                    radius: AppTheme.isDark ? 20 : 14,
                    y: AppTheme.isDark ? 2 : 7)
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
            .background(configuration.isPressed ? AppTheme.cardHover : AppTheme.card)
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.accent.opacity(AppTheme.isDark ? 0.3 : 0.4), lineWidth: 1))
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
            .shadow(color: AppTheme.isDark ? AppTheme.danger.opacity(0.25) : Color.clear,
                    radius: 12, y: 2)
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
            .background(color.opacity(AppTheme.isDark ? 0.12 : 0.15))
            .cornerRadius(100)
            .overlay(Capsule().strokeBorder(color.opacity(AppTheme.isDark ? 0.2 : 0.3), lineWidth: 1))
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
                        colors: [.clear, Color.white.opacity(AppTheme.isDark ? 0.04 : 0.45), .clear],
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

// MARK: - Subtle Inner Glow (dark mode depth effect on cards)
struct InnerGlowModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: AppTheme.isDark
                                ? [Color.white.opacity(0.06), Color.clear, Color.clear]
                                : [Color.clear],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func themeCard(padding: CGFloat = 16) -> some View { modifier(ThemeCard(padding: padding)) }
    func glassCard(cornerRadius: CGFloat = 16) -> some View { modifier(GlassCard(cornerRadius: cornerRadius)) }
    func shimmer() -> some View { modifier(ShimmerModifier()) }
    func innerGlow(cornerRadius: CGFloat = 16) -> some View { modifier(InnerGlowModifier(cornerRadius: cornerRadius)) }
}
