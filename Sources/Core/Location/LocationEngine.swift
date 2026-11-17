import Foundation
import CoreLocation
import Observation

/// Orchestrateur central de télémétrie de GeoShift.
/// Coordonne le basculement entre récepteur matériel réel et simulation sandbox,
/// et gère le géocodage inverse régulé (throttled & cached).
@Observable
@MainActor
public final class LocationEngine {
    // Fournisseurs
    public let realProvider: RealLocationProvider
    public let simulatedProvider: SimulatedLocationProvider

    // État actif
    public private(set) var activeSource: TelemetrySource = .realHardware
    public private(set) var currentSnapshot: TelemetrySnapshot

    // Tâches asynchrones de souscription
    private var realStreamTask: Task<Void, Never>?
    private var simStreamTask: Task<Void, Never>?

    // Sous-système de géocodage inverse avec cache et limitation de débit (Throttling)
    private let geocoder = CLGeocoder()
    private var geocodeCache: [String: (place: String, country: String)] = [:]
    private var lastGeocodeTimestamp: Date = .distantPast
    private var isGeocodingInProgress: Bool = false

    public init() {
        self.realProvider = RealLocationProvider()
        self.simulatedProvider = SimulatedLocationProvider()

        // Position initiale par défaut (ex: Tour Eiffel, Paris) en attendant la première acquisition
        let defaultCoord = CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350)
        self.currentSnapshot = TelemetrySnapshot(
            coordinate: defaultCoord,
            altitude: 35.0,
            horizontalAccuracy: 5.0,
            course: 0.0,
            speed: 0.0,
            timestamp: Date(),
            source: .realHardware,
            placeName: "Paris",
            country: "France"
        )

        setupSubscriptions()
        startRealHardware()
    }

    deinit {
        realStreamTask?.cancel()
        simStreamTask?.cancel()
    }

    // MARK: - Basculement de Source

    /// Active l'acquisition GPS matérielle réelle.
    public func startRealHardware() {
        activeSource = .realHardware
        simulatedProvider.stop()
        realProvider.start()
    }

    /// Bascule sur une position simulée fixe.
    public func simulateFixedCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        altitude: Double = 35.0,
        accuracy: Double = 5.0
    ) {
        activeSource = .localSimulation
        realProvider.stop()
        simulatedProvider.setFixedLocation(coordinate: coordinate, altitude: altitude, accuracy: accuracy)
    }

    /// Charge et lance la simulation d'un itinéraire composé de multiples coordonnées.
    public func simulateRoute(
        coordinates: [CLLocationCoordinate2D],
        config: SimulationConfig? = nil
    ) {
        activeSource = .localSimulation
        realProvider.stop()
        if let config {
            simulatedProvider.config = config
        }
        simulatedProvider.loadRoute(coordinates: coordinates)
        simulatedProvider.play()
    }

    /// Reprend la lecture du parcours en simulation.
    public func resumeSimulation() {
        simulatedProvider.resume()
    }

    /// Met en pause la simulation en cours.
    public func pauseSimulation() {
        simulatedProvider.pause()
    }

    /// Arrête la simulation et remet l'itinéraire au point de départ.
    public func stopSimulation() {
        simulatedProvider.stop()
    }

    /// Déplace la tête de lecture de l'itinéraire simulé.
    public func seekSimulation(to progress: Double) {
        simulatedProvider.seek(to: progress)
    }

    // MARK: - Propriétés Dérivées

    public var isSimulating: Bool {
        activeSource == .localSimulation
    }

    public var simulationPlaybackState: SimulatedLocationProvider.PlaybackState {
        simulatedProvider.playbackState
    }

    public var simulationProgress: Double {
        simulatedProvider.currentProgress
    }

    public var simulationDistance: Double {
        simulatedProvider.currentDistanceMeters
    }

    public var simulationTotalDistance: Double {
        simulatedProvider.totalDistanceMeters
    }

    public var simulationElapsedTime: Double {
        simulatedProvider.elapsedTimeSeconds
    }

    // MARK: - Abonnements aux Flux

    private func setupSubscriptions() {
        // Flux matériel
        realStreamTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in self.realProvider.telemetryStream {
                guard !Task.isCancelled else { break }
                if self.activeSource == .realHardware {
                    self.updateSnapshot(snapshot)
                }
            }
        }

        // Flux simulation
        simStreamTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in self.simulatedProvider.telemetryStream {
                guard !Task.isCancelled else { break }
                if self.activeSource == .localSimulation {
                    self.updateSnapshot(snapshot)
                }
            }
        }
    }

    private func updateSnapshot(_ newSnapshot: TelemetrySnapshot) {
        // Conserve le lieu actuel s'il n'est pas encore géocodé
        var enriched = TelemetrySnapshot(
            coordinate: newSnapshot.coordinate,
            altitude: newSnapshot.altitude,
            horizontalAccuracy: newSnapshot.horizontalAccuracy,
            course: newSnapshot.course,
            speed: newSnapshot.speed,
            timestamp: newSnapshot.timestamp,
            source: newSnapshot.source,
            placeName: currentSnapshot.placeName,
            country: currentSnapshot.country
        )

        // Vérification dans le cache de géocodage
        let cacheKey = makeGeocodeKey(for: newSnapshot.coordinate)
        if let cached = geocodeCache[cacheKey] {
            enriched = TelemetrySnapshot(
                coordinate: enriched.coordinate,
                altitude: enriched.altitude,
                horizontalAccuracy: enriched.horizontalAccuracy,
                course: enriched.course,
                speed: enriched.speed,
                timestamp: enriched.timestamp,
                source: enriched.source,
                placeName: cached.place,
                country: cached.country
            )
        } else {
            // Déclenche une demande avec étranglement (Throttling max 1 requete / 3 sec)
            requestReverseGeocodeIfNeeded(for: newSnapshot.coordinate, cacheKey: cacheKey)
        }

        self.currentSnapshot = enriched
    }

    // MARK: - Géocodage Inverse avec Cache et Étranglement

    private func makeGeocodeKey(for coord: CLLocationCoordinate2D) -> String {
        // Résolution à ~100m (3 décimales)
        let latRound = (coord.latitude * 1000).rounded() / 1000
        let lonRound = (coord.longitude * 1000).rounded() / 1000
        return "\(latRound),\(lonRound)"
    }

    private func requestReverseGeocodeIfNeeded(for coord: CLLocationCoordinate2D, cacheKey: String) {
        guard !isGeocodingInProgress else { return }
        let now = Date()
        guard now.timeIntervalSince(lastGeocodeTimestamp) >= 3.0 else { return }

        isGeocodingInProgress = true
        lastGeocodeTimestamp = now

        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isGeocodingInProgress = false

                if let placemark = placemarks?.first {
                    let place = placemark.locality ?? placemark.name ?? placemark.subLocality ?? "Lieu inconnu"
                    let country = placemark.country ?? ""

                    self.geocodeCache[cacheKey] = (place: place, country: country)

                    // Met à jour l'instantané si la coordonnée correspondante est toujours proche
                    if self.makeGeocodeKey(for: self.currentSnapshot.coordinate) == cacheKey {
                        self.currentSnapshot = TelemetrySnapshot(
                            coordinate: self.currentSnapshot.coordinate,
                            altitude: self.currentSnapshot.altitude,
                            horizontalAccuracy: self.currentSnapshot.horizontalAccuracy,
                            course: self.currentSnapshot.course,
                            speed: self.currentSnapshot.speed,
                            timestamp: self.currentSnapshot.timestamp,
                            source: self.currentSnapshot.source,
                            placeName: place,
                            country: country
                        )
                    }
                }
            }
        }
    }
}
