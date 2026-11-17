import SwiftUI
import MapKit
import CoreLocation
import SwiftData

/// Vue principale du tableau de bord affichant la carte interactive MapKit iOS 17 et la télémétrie en direct.
public struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()

    public init() {}

    public var body: some View {
        let snapshot = appState.locationEngine.currentSnapshot

        ZStack(alignment: .top) {
            // Carte MapKit iOS 17
            MapReader { mapProxy in
                Map(position: $viewModel.cameraPosition) {
                    // Annotation de la position active (Réelle ou Simulée)
                    Annotation(
                        snapshot.placeName ?? "Position Active",
                        coordinate: snapshot.coordinate
                    ) {
                        ActiveLocationMarker(
                            course: snapshot.course,
                            isSimulation: snapshot.source.isSimulation,
                            isMoving: snapshot.isMoving
                        )
                    }

                    // Épingle sélectionnée par l'utilisateur
                    if let pinned = viewModel.selectedCoordinate {
                        Annotation("Sélection", coordinate: pinned) {
                            SelectedPinMarker {
                                viewModel.prepareManualSimulation(initial: pinned)
                            }
                        }
                    }
                }
                .mapStyle(currentMapStyle)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onTapGesture(coordinateSpace: .local) { screenPoint in
                    if let coord = mapProxy.convert(screenPoint, from: .local) {
                        appState.triggerHapticFeedback(.light)
                        viewModel.handleMapLongPress(at: coord)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            // Barres et Commandes Flottantes
            VStack {
                // Barre Supérieure : Recherche, Recentrage et Style de Carte
                HStack(spacing: 10) {
                    Button {
                        viewModel.isSearchPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(GeoTheme.accentPrimary)
                            Text("Rechercher ville, adresse...")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(GeoTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(.ultraThinMaterial)
                        .background(GeoTheme.backgroundSecondary.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // Bouton Style Carte
                    Menu {
                        ForEach(AppMapStyle.allCases) { style in
                            Button {
                                appState.mapStyle = style
                            } label: {
                                Label(style.rawValue, systemImage: style.sfSymbol)
                            }
                        }
                    } label: {
                        Image(systemName: appState.mapStyle.sfSymbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(GeoTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial)
                            .background(GeoTheme.backgroundSecondary.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }

                    // Bouton Recentrage Caméra
                    Button {
                        viewModel.centerOnCoordinate(snapshot.coordinate)
                        appState.triggerHapticFeedback(.light)
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(GeoTheme.accentPrimary)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial)
                            .background(GeoTheme.backgroundSecondary.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // HUD Télémétrique Flottant Inférieur
                TelemetryHUDView(
                    snapshot: snapshot,
                    isMetric: appState.isMetric,
                    isExpanded: $viewModel.isTelemetryExpanded,
                    onOpenSimulation: {
                        viewModel.prepareManualSimulation(initial: snapshot.coordinate)
                    },
                    onRestoreRealGPS: {
                        appState.restoreRealGPS()
                    },
                    onCopyCoordinates: {
                        let text = CoordinateFormatter.formatCompact(snapshot.coordinate)
                        UIPasteboard.general.string = text
                        appState.showToast("Coordonnées copiées : \(text)")
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $viewModel.isQuickSimulationPresented) {
            QuickSimulationSheet(
                initialCoordinate: viewModel.selectedCoordinate ?? snapshot.coordinate,
                initialAltitude: snapshot.altitude,
                initialAccuracy: snapshot.horizontalAccuracy
            )
        }
        .sheet(isPresented: $viewModel.isSearchPresented) {
            LocationSearchView { selectedCoord, placeName in
                viewModel.centerOnCoordinate(selectedCoord)
                viewModel.selectedCoordinate = selectedCoord
                viewModel.isQuickSimulationPresented = true
            }
        }
        .onAppear {
            viewModel.centerOnCoordinate(snapshot.coordinate)
        }
    }

    private var currentMapStyle: MapStyle {
        switch appState.mapStyle {
        case .standard: return .standard(elevation: .realistic)
        case .hybrid: return .hybrid(elevation: .realistic)
        case .satellite: return .imagery(elevation: .realistic)
        }
    }
}

// MARK: - Marqueurs Personnalisés MapKit

private struct ActiveLocationMarker: View {
    let course: Double
    let isSimulation: Bool
    let isMoving: Bool

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            // Anneau pulsant
            Circle()
                .stroke(isSimulation ? GeoTheme.accentPrimary.opacity(0.3) : GeoTheme.statusSuccess.opacity(0.3), lineWidth: 2)
                .frame(width: 44, height: 44)
                .scaleEffect(pulse ? 1.4 : 0.9)
                .opacity(pulse ? 0.0 : 0.8)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: pulse)

            // Disque principal
            Circle()
                .fill(isSimulation ? GeoTheme.accentPrimary : GeoTheme.statusSuccess)
                .frame(width: 26, height: 26)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)

            // Flèche indicatrice de cap
            if course >= 0.0 {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.white)
                    .rotationEffect(.degrees(course))
            }
        }
        .onAppear {
            pulse = true
        }
    }
}

private struct SelectedPinMarker: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 0) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(GeoTheme.accentSecondary)
                    .background(Circle().fill(Color.white).padding(2))
                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 4)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(GeoTheme.accentSecondary)
                    .offset(y: -4)
            }
        }
        .buttonStyle(.plain)
    }
}
