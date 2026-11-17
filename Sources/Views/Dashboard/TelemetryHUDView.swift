import SwiftUI
import CoreLocation

/// Panneau d'affichage tête haute (HUD) présentant la télémétrie en temps réel au-dessus de la carte.
public struct TelemetryHUDView: View {
    public let snapshot: TelemetrySnapshot
    public let isMetric: Bool
    @Binding public var isExpanded: Bool
    public let onOpenSimulation: () -> Void
    public let onRestoreRealGPS: () -> Void
    public let onCopyCoordinates: () -> Void

    public var body: some View {
        VStack(spacing: 12) {
            // Barre supérieure d'en-tête
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.placeName ?? "Localisation active")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(GeoTheme.textPrimary)
                        .lineLimit(1)

                    if let country = snapshot.country, !country.isEmpty {
                        Text(country)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(GeoTheme.textSecondary)
                    }
                }

                Spacer()

                GPSStatusBadge(source: snapshot.source)

                Button {
                    withAnimation(GeoTheme.springAnimation) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(GeoTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                // Coordonnées complètes
                CoordinateDisplayBox(coordinate: snapshot.coordinate)

                // Grille 2x2 des indicateurs télémétriques
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    TelemetryValuePill(
                        icon: "speedometer",
                        label: "Vitesse",
                        value: CoordinateFormatter.formatSpeed(snapshot.speed, isMetric: isMetric),
                        accentColor: GeoTheme.accentPrimary
                    )

                    TelemetryValuePill(
                        icon: "location.north.circle.fill",
                        label: "Cap (Course)",
                        value: CoordinateFormatter.formatCourse(snapshot.course),
                        accentColor: GeoTheme.accentSecondary
                    )

                    TelemetryValuePill(
                        icon: "mountain.2.fill",
                        label: "Altitude",
                        value: CoordinateFormatter.formatAltitude(snapshot.altitude, isMetric: isMetric),
                        accentColor: GeoTheme.statusWarning
                    )

                    TelemetryValuePill(
                        icon: "scope",
                        label: "Précision",
                        value: CoordinateFormatter.formatAccuracy(snapshot.horizontalAccuracy, isMetric: isMetric),
                        accentColor: GeoTheme.statusSuccess
                    )
                }

                // Boutons d'action rapide
                HStack(spacing: 8) {
                    if snapshot.source == .localSimulation {
                        Button {
                            onRestoreRealGPS()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("GPS Réel")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GeoSecondaryButtonStyle(isCompact: true))
                    }

                    Button {
                        onOpenSimulation()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Simuler")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GeoPrimaryButtonStyle(isCompact: true))

                    Button {
                        onCopyCoordinates()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(GeoSecondaryButtonStyle(isCompact: true))
                }
            }
        }
        .padding(14)
        .glassPanel(cornerRadius: 18)
    }
}
