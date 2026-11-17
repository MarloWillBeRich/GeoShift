import Foundation
import SwiftUI
import MapKit
import Observation
import CoreLocation

/// ViewModel gérant la planification d'itinéraires, le calcul via MKDirections et le lecteur de simulation dynamique.
@Observable
@MainActor
public final class RouteSimulationViewModel {
    // Jalons d'itinéraire
    public var waypoints: [RouteWaypoint] = []
    public var calculatedRoute: CalculatedRoute?
    public var routeName: String = "Nouvel Itinéraire"

    // Configuration de simulation
    public var speedPreset: SimulationSpeedPreset = .cityDriving {
        didSet {
            updateSpeed()
        }
    }
    public var customSpeedKmh: Double = 50.0 {
        didSet {
            if speedPreset == .custom {
                updateSpeed()
            }
        }
    }
    public var loopRoute: Bool = false {
        didSet {
            simulationConfig.loopRoute = loopRoute
        }
    }
    public var addGpsJitter: Bool = false {
        didSet {
            simulationConfig.addGpsJitter = addGpsJitter
        }
    }
    public var transportType: MKDirectionsTransportType = .automobile

    // État d'exécution
    public var isCalculating: Bool = false
    public var errorMessage: String?
    public var exportedGPXURL: URL?
    public var isShareSheetPresented: Bool = false

    // Configuration interne
    public var simulationConfig: SimulationConfig = .standard

    public init() {
        self.simulationConfig = SimulationConfig(
            speedMetersPerSecond: speedPreset.metersPerSecond,
            horizontalAccuracy: 5.0,
            altitude: 35.0,
            loopRoute: false,
            addGpsJitter: false,
            jitterRadiusMeters: 2.0,
            updateFrequencyHz: 10.0
        )
    }

    private func updateSpeed() {
        let speedMps: Double
        if speedPreset == .custom {
            speedMps = max(0.5, customSpeedKmh / 3.6)
        } else {
            speedMps = speedPreset.metersPerSecond
        }
        simulationConfig.speedMetersPerSecond = speedMps
    }

    // MARK: - Gestion des Waypoints

    /// Ajoute un jalon au parcours.
    public func addWaypoint(name: String, coordinate: CLLocationCoordinate2D) {
        let waypoint = RouteWaypoint(
            name: name.isEmpty ? "Étape \(waypoints.count + 1)" : name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            altitude: 35.0
        )
        waypoints.append(waypoint)
    }

    /// Supprime un jalon à l'index donné.
    public func removeWaypoint(at offsets: IndexSet) {
        waypoints.remove(atOffsets: offsets)
        calculatedRoute = nil
    }

    /// Réorganise les jalons.
    public func moveWaypoint(from source: IndexSet, to destination: Int) {
        waypoints.move(fromOffsets: source, toOffset: destination)
        calculatedRoute = nil
    }

    /// Vide la liste des jalons.
    public func clearAll() {
        waypoints.removeAll()
        calculatedRoute = nil
        errorMessage = nil
    }

    /// Charge un itinéraire sauvegardé en mémoire.
    public func loadSavedRoute(_ route: SavedRoute) {
        self.routeName = route.name
        self.waypoints = route.waypoints
        Task {
            await calculateCurrentRoute()
        }
    }

    // MARK: - Calcul de l'Itinéraire

    /// Lance le calcul du tracé routier avec MKDirections.
    public func calculateCurrentRoute() async {
        guard waypoints.count >= 2 else {
            errorMessage = "Veuillez ajouter au moins 2 points pour calculer un itinéraire."
            return
        }

        isCalculating = true
        errorMessage = nil

        let coords = waypoints.map { $0.coordinate }

        do {
            let result = try await RouteCalculatorService.calculateRoute(
                between: coords,
                transportType: transportType
            )
            self.calculatedRoute = result
            self.isCalculating = false
        } catch {
            self.errorMessage = "Échec du calcul : \(error.localizedDescription)"
            self.isCalculating = false
        }
    }

    // MARK: - Exportation GPX Xcode Compatible

    /// Génère le fichier GPX et prépare l'URL temporaire de partage.
    public func prepareGPXExport() {
        let coordinatesToExport: [CLLocationCoordinate2D]
        if let calculated = calculatedRoute, !calculated.coordinates.isEmpty {
            coordinatesToExport = calculated.coordinates
        } else {
            coordinatesToExport = waypoints.map { $0.coordinate }
        }

        guard !coordinatesToExport.isEmpty else {
            errorMessage = "Aucun tracé à exporter en GPX."
            return
        }

        let gpxContent = GPXExporter.generateRouteGPX(
            name: routeName,
            coordinates: coordinatesToExport,
            speedMetersPerSecond: simulationConfig.speedMetersPerSecond,
            altitude: simulationConfig.altitude
        )

        if let fileURL = GPXExporter.createTemporaryGPXFile(content: gpxContent, filename: routeName) {
            self.exportedGPXURL = fileURL
            self.isShareSheetPresented = true
        } else {
            self.errorMessage = "Impossible de créer le fichier d'export GPX."
        }
    }
}
