import SwiftUI
import MapKit
import SwiftData
import CoreLocation

/// Vue complète de planification, calcul multi-étapes et simulation dynamique d'itinéraires.
public struct RoutePlannerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = RouteSimulationViewModel()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isAddWaypointPresented: Bool = false
    @State private var isSaveRoutePresented: Bool = false
    @State private var isShowingSavedRoutesList: Bool = false

    @Query(sort: \SavedRoute.createdAt, order: .reverse)
    private var savedRoutes: [SavedRoute]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                GeoTheme.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Carte Interactive de Visualisation du Tracé
                    Map(position: $cameraPosition) {
                        // Tracé routier calculé
                        if let calculated = viewModel.calculatedRoute, !calculated.coordinates.isEmpty {
                            MapPolyline(coordinates: calculated.coordinates)
                                .stroke(GeoTheme.accentPrimary, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        }

                        // Marqueurs de chaque jalon
                        ForEach(Array(viewModel.waypoints.enumerated()), id: \.element.id) { index, waypoint in
                            Annotation(waypoint.name, coordinate: waypoint.coordinate) {
                                WaypointMarker(index: index + 1, isDestination: index == viewModel.waypoints.count - 1)
                            }
                        }

                        // Curseur de la simulation en cours
                        if appState.locationEngine.isSimulating {
                            Annotation("Position Simulée", coordinate: appState.locationEngine.currentSnapshot.coordinate) {
                                Circle()
                                    .fill(GeoTheme.accentPrimary)
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Liste des Jalons & Actions
                    ScrollView {
                        VStack(spacing: 16) {
                            // En-tête Nom de l'itinéraire & Mode
                            VStack(spacing: 10) {
                                TextField("Nom de l'itinéraire", text: $viewModel.routeName)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(GeoTheme.textPrimary)
                                    .textFieldStyle(GeoTextFieldStyle())

                                Picker("Mode de Transport", selection: $viewModel.transportType) {
                                    Label("Voiture", systemImage: "car.fill").tag(MKDirectionsTransportType.automobile)
                                    Label("À pied", systemImage: "figure.walk").tag(MKDirectionsTransportType.walking)
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(14)
                            .cardSurface()

                            // Liste ordonnée des étapes
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("ÉTAPES (\(viewModel.waypoints.count))")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(GeoTheme.textSecondary)

                                    Spacer()

                                    Button {
                                        isAddWaypointPresented = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Ajouter")
                                        }
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(GeoTheme.accentPrimary)
                                    }
                                }

                                if viewModel.waypoints.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "map")
                                            .font(.system(size: 28))
                                            .foregroundStyle(GeoTheme.textSecondary)
                                        Text("Aucun point ajouté. Cliquez sur Ajouter pour définir un point de départ.")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundStyle(GeoTheme.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                                } else {
                                    ForEach(Array(viewModel.waypoints.enumerated()), id: \.element.id) { index, waypoint in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(index == 0 ? GeoTheme.statusSuccess : (index == viewModel.waypoints.count - 1 ? GeoTheme.statusError : GeoTheme.accentPrimary))
                                                .frame(width: 24, height: 24)
                                                .overlay(
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(Color.white)
                                                )

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(waypoint.name)
                                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(GeoTheme.textPrimary)

                                                Text(CoordinateFormatter.formatCompact(waypoint.coordinate))
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundStyle(GeoTheme.textSecondary)
                                            }

                                            Spacer()

                                            Button {
                                                if let idx = viewModel.waypoints.firstIndex(where: { $0.id == waypoint.id }) {
                                                    viewModel.removeWaypoint(at: IndexSet(integer: idx))
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(GeoTheme.textSecondary)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 10)
                                        .background(GeoTheme.backgroundSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                            .padding(14)
                            .cardSurface()

                            // Bouton Calcul Itinéraire
                            if viewModel.waypoints.count >= 2 {
                                Button {
                                    Task {
                                        await viewModel.calculateCurrentRoute()
                                        if let coords = viewModel.calculatedRoute?.coordinates, !coords.isEmpty {
                                            cameraPosition = .automatic
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if viewModel.isCalculating {
                                            ProgressView()
                                                .tint(Color.white)
                                        } else {
                                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                            Text("Calculer l'Itinéraire")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(GeoPrimaryButtonStyle())
                                .disabled(viewModel.isCalculating)
                            }

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(GeoTheme.statusError)
                                    .padding(.horizontal, 8)
                            }

                            // Résumé du Calcul
                            if let calculated = viewModel.calculatedRoute {
                                VStack(spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("DISTANCE TOTALE")
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundStyle(GeoTheme.textSecondary)
                                            Text(CoordinateFormatter.formatDistance(calculated.totalDistanceMeters, isMetric: appState.isMetric))
                                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                                .foregroundStyle(GeoTheme.textPrimary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("DURÉE ESTIMÉE")
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundStyle(GeoTheme.textSecondary)
                                            Text(CoordinateFormatter.formatDuration(calculated.expectedDurationSeconds))
                                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                                .foregroundStyle(GeoTheme.textPrimary)
                                        }
                                    }

                                    Button {
                                        saveRouteToSwiftData()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "square.and.arrow.down.fill")
                                            Text("Sauvegarder cet Itinéraire")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(GeoSecondaryButtonStyle(isCompact: true))
                                }
                                .padding(14)
                                .cardSurface()
                            }

                            // Marge inférieure pour éviter le chevauchement avec la barre de lecteur
                            Spacer().frame(height: 140)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }

                // Barre de Contrôle du Lecteur en bas
                if let calculated = viewModel.calculatedRoute, !calculated.coordinates.isEmpty {
                    RoutePlayerControlBar(
                        playbackState: appState.locationEngine.simulationPlaybackState,
                        progress: appState.locationEngine.simulationProgress,
                        currentDistance: appState.locationEngine.simulationDistance,
                        totalDistance: appState.locationEngine.simulationTotalDistance > 0 ? appState.locationEngine.simulationTotalDistance : calculated.totalDistanceMeters,
                        elapsedTime: appState.locationEngine.simulationElapsedTime,
                        isMetric: appState.isMetric,
                        speedPreset: $viewModel.speedPreset,
                        loopRoute: $viewModel.loopRoute,
                        addGpsJitter: $viewModel.addGpsJitter,
                        onPlay: {
                            appState.locationEngine.simulateRoute(
                                coordinates: calculated.coordinates,
                                config: viewModel.simulationConfig
                            )
                        },
                        onPause: {
                            appState.locationEngine.pauseSimulation()
                        },
                        onStop: {
                            appState.locationEngine.stopSimulation()
                        },
                        onSeek: { target in
                            appState.locationEngine.seekSimulation(to: target)
                        },
                        onExportGPX: {
                            viewModel.prepareGPXExport()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Itinéraires & Simulateur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            loadParisDemo()
                        } label: {
                            Label("Charger Démo Paris", systemImage: "sparkles")
                        }

                        if !savedRoutes.isEmpty {
                            Menu("Itinéraires Sauvegardés") {
                                ForEach(savedRoutes) { route in
                                    Button(route.name) {
                                        viewModel.loadSavedRoute(route)
                                    }
                                }
                            }
                        }

                        Button(role: .destructive) {
                            viewModel.clearAll()
                        } label: {
                            Label("Tout effacer", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(GeoTheme.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $isAddWaypointPresented) {
                LocationSearchView { coord, name in
                    viewModel.addWaypoint(name: name, coordinate: coord)
                    Task {
                        if viewModel.waypoints.count >= 2 {
                            await viewModel.calculateCurrentRoute()
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShareSheetPresented) {
                if let url = viewModel.exportedGPXURL {
                    ShareSheetView(activityItems: [url])
                }
            }
        }
    }

    private func saveRouteToSwiftData() {
        guard let calculated = viewModel.calculatedRoute else { return }

        let saved = SavedRoute(
            name: viewModel.routeName.isEmpty ? "Itinéraire \(Date().formatted())" : viewModel.routeName,
            waypoints: viewModel.waypoints,
            distanceMeters: calculated.totalDistanceMeters,
            expectedDurationSeconds: calculated.expectedDurationSeconds
        )
        modelContext.insert(saved)

        let entry = HistoryEntry(
            actionType: .routeSimulated,
            title: saved.name,
            subtitle: "\(CoordinateFormatter.formatDistance(saved.distanceMeters, isMetric: appState.isMetric))",
            latitude: viewModel.waypoints.first?.latitude ?? 0.0,
            longitude: viewModel.waypoints.first?.longitude ?? 0.0
        )
        modelContext.insert(entry)

        appState.showToast("Itinéraire sauvegardé avec succès")
    }

    private func loadParisDemo() {
        viewModel.clearAll()
        viewModel.routeName = "Traversée de Paris (Tour Eiffel → Louvre)"
        viewModel.addWaypoint(name: "Tour Eiffel", coordinate: CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350))
        viewModel.addWaypoint(name: "Place de la Concorde", coordinate: CLLocationCoordinate2D(latitude: 48.865633, longitude: 2.321236))
        viewModel.addWaypoint(name: "Musée du Louvre", coordinate: CLLocationCoordinate2D(latitude: 48.860611, longitude: 2.337644))

        Task {
            await viewModel.calculateCurrentRoute()
        }
    }
}

// MARK: - Marqueur de Jalon

private struct WaypointMarker: View {
    let index: Int
    let isDestination: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isDestination ? GeoTheme.statusError : GeoTheme.accentPrimary)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))

                Text("\(index)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .shadow(radius: 4)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(isDestination ? GeoTheme.statusError : GeoTheme.accentPrimary)
                .offset(y: -2)
        }
    }
}

// MARK: - Share Sheet UIKit Wrapper

public struct ShareSheetView: UIViewControllerRepresentable {
    public let activityItems: [Any]

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
