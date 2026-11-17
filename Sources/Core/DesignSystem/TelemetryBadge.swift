import SwiftUI
import CoreLocation

/// Badge d'état signalant explicitement la provenance du flux GPS (Matériel réel vs Simulation Sandbox).
public struct GPSStatusBadge: View {
    public let source: TelemetrySource

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(source.isSimulation ? GeoTheme.accentPrimary : GeoTheme.statusSuccess)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(source.isSimulation ? GeoTheme.accentPrimary.opacity(0.5) : GeoTheme.statusSuccess.opacity(0.5), lineWidth: 4)
                        .scaleEffect(source.isSimulation ? 1.4 : 1.2)
                )

            Text(source.rawValue)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(source.isSimulation ? GeoTheme.accentPrimary : GeoTheme.statusSuccess)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            (source.isSimulation ? GeoTheme.accentPrimary : GeoTheme.statusSuccess).opacity(0.12)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke((source.isSimulation ? GeoTheme.accentPrimary : GeoTheme.statusSuccess).opacity(0.3), lineWidth: 1)
        )
    }
}

/// Pilule modulaire affichant une métrique télémétrique avec typographie monospacée.
public struct TelemetryValuePill: View {
    public let icon: String
    public let label: String
    public let value: String
    public var accentColor: Color = GeoTheme.accentPrimary

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(GeoTheme.textSecondary)
            }

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(GeoTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeoTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

/// Affichage élégant des coordonnées géographiques en deux lignes monospacées.
public struct CoordinateDisplayBox: View {
    public let coordinate: CLLocationCoordinate2D

    public var body: some View {
        let (latStr, lonStr) = CoordinateFormatter.formatDecimalWithHemisphere(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            fractionDigits: 6
        )

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LATITUDE")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(GeoTheme.textSecondary)
                Text(latStr)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(GeoTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 2) {
                Text("LONGITUDE")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(GeoTheme.textSecondary)
                Text(lonStr)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(GeoTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(GeoTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
