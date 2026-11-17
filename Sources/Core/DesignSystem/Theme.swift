import SwiftUI

/// Système de design centralisé Apple Dark Premium pour GeoShift.
public enum GeoTheme {

    // MARK: - Palette Hexadécimale Stricte

    public static let backgroundPrimary = Color(hex: "#090B10")
    public static let backgroundSecondary = Color(hex: "#121722")
    public static let cardSurface = Color(hex: "#171E2B")
    public static let accentPrimary = Color(hex: "#48A9FF")
    public static let accentSecondary = Color(hex: "#7C6CFF")
    public static let statusSuccess = Color(hex: "#35D49A")
    public static let statusWarning = Color(hex: "#FFB84D")
    public static let statusError = Color(hex: "#FF5C5C")
    public static let textPrimary = Color(hex: "#F5F7FA")
    public static let textSecondary = Color(hex: "#929BAC")

    // MARK: - Animations Systèmes

    public static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.82)
    public static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.88)
}

// MARK: - Extension Color pour Hexadécimal

extension Color {
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - Modifieurs de Cartes et Panneaux

public struct CardSurfaceModifier: ViewModifier {
    public var cornerRadius: CGFloat = 16.0

    public func body(content: Content) -> some View {
        content
            .background(GeoTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

public struct GlassPanelModifier: ViewModifier {
    public var cornerRadius: CGFloat = 20.0

    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(GeoTheme.backgroundSecondary.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

extension View {
    public func cardSurface(cornerRadius: CGFloat = 16.0) -> some View {
        self.modifier(CardSurfaceModifier(cornerRadius: cornerRadius))
    }

    public func glassPanel(cornerRadius: CGFloat = 20.0) -> some View {
        self.modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Styles de Boutons

public struct GeoPrimaryButtonStyle: ButtonStyle {
    public var color: Color = GeoTheme.accentPrimary
    public var isCompact: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(isCompact ? .subheadline : .headline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.vertical, isCompact ? 8 : 14)
            .padding(.horizontal, isCompact ? 14 : 20)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: color.opacity(configuration.isPressed ? 0.15 : 0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(GeoTheme.quickSpring, value: configuration.isPressed)
    }
}

public struct GeoSecondaryButtonStyle: ButtonStyle {
    public var isCompact: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(isCompact ? .subheadline : .headline, design: .rounded).weight(.medium))
            .foregroundStyle(GeoTheme.textPrimary)
            .padding(.vertical, isCompact ? 8 : 14)
            .padding(.horizontal, isCompact ? 14 : 20)
            .background(GeoTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(GeoTheme.quickSpring, value: configuration.isPressed)
    }
}

public struct GeoTextFieldStyle: TextFieldStyle {
    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(GeoTheme.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(GeoTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Feuille de Partage Système UIKit (AirDrop, Fichiers, Messages)

public struct ShareSheetView: UIViewControllerRepresentable {
    public let activityItems: [Any]

    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
