import SwiftUI
import CoreLocation

/// Barre de contrôle de lecture physique d'itinéraire (Play, Pause, Stop, Vitesse, Progression, Export GPX).
public struct RoutePlayerControlBar: View {
    public let playbackState: SimulatedLocationProvider.PlaybackState
    public let progress: Double
    public let currentDistance: Double
    public let totalDistance: Double
    public let elapsedTime: Double
    public let isMetric: Bool

    @Binding public var speedPreset: SimulationSpeedPreset
    @Binding public var loopRoute: Bool
    @Binding public var addGpsJitter: Bool

    public let onPlay: () -> Void
    public let onPause: () -> Void
    public let onStop: () -> Void
    public let onSeek: (Double) -> Void
    public let onExportGPX: () -> Void

    public var body: some View {
        VStack(spacing: 12) {
            // Ligne de Progression et Temps
            VStack(spacing: 4) {
                HStack {
                    Text(CoordinateFormatter.formatDuration(elapsedTime))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(GeoTheme.textPrimary)

                    Spacer()

                    Text("\(CoordinateFormatter.formatDistance(currentDistance, isMetric: isMetric)) / \(CoordinateFormatter.formatDistance(totalDistance, isMetric: isMetric))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(GeoTheme.textSecondary)
                }

                // Slider interactif de défilement
                Slider(
                    value: Binding(
                        get: { progress },
                        set: { onSeek($0) }
                    ),
                    in: 0.0...1.0
                )
                .tint(GeoTheme.accentPrimary)
            }

            // Sélecteur de Préréglages de Vitesse
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SimulationSpeedPreset.allCases) { preset in
                        Button {
                            speedPreset = preset
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: preset.sfSymbol)
                                    .font(.system(size: 11))
                                Text(preset.shortName)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(speedPreset == preset ? GeoTheme.accentPrimary : GeoTheme.cardSurface)
                            .foregroundStyle(speedPreset == preset ? Color.white : GeoTheme.textSecondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            // Boutons de Commande Principaux & Options
            HStack(spacing: 12) {
                // Bouton Boucle
                Button {
                    loopRoute.toggle()
                } label: {
                    Image(systemName: loopRoute ? "repeat.1.circle.fill" : "repeat.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(loopRoute ? GeoTheme.accentPrimary : GeoTheme.textSecondary)
                }
                .buttonStyle(.plain)

                // Bouton Micro-bruit GPS
                Button {
                    addGpsJitter.toggle()
                } label: {
                    Image(systemName: addGpsJitter ? "waveform.path.badge.plus" : "waveform.path")
                        .font(.system(size: 20))
                        .foregroundStyle(addGpsJitter ? GeoTheme.statusWarning : GeoTheme.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Contrôles Play / Pause / Stop
                HStack(spacing: 10) {
                    Button {
                        onStop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(GeoTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(GeoTheme.cardSurface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if playbackState == .playing {
                            onPause()
                        } else {
                            onPlay()
                        }
                    } label: {
                        Image(systemName: playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 52, height: 52)
                            .background(GeoTheme.accentPrimary)
                            .clipShape(Circle())
                            .shadow(color: GeoTheme.accentPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Bouton Export GPX
                Button {
                    onExportGPX()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("GPX")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GeoTheme.accentSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(GeoTheme.accentSecondary.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(GeoTheme.accentSecondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .glassPanel(cornerRadius: 18)
    }
}
