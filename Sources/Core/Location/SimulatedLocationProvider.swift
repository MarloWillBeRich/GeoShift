import Foundation
import CoreLocation

/// Fournisseur de télémétrie de simulation capable d'opérer en mode statique (position fixe)
/// ou en mode dynamique (défilement physique le long d'un itinéraire avec interpolation).
@MainActor
public final class SimulatedLocationProvider: LocationProviderProtocol {
    public enum Mode: Sendable, Equatable {
        case idle
        case fixed(CLLocationCoordinate2D)
        case route(coordinates: [CLLocationCoordinate2D])
    }

    public enum PlaybackState: Sendable, Equatable {
        case stopped
        case playing
        case paused
    }

    private var continuation: AsyncStream<TelemetrySnapshot>.Continuation?
    private var simulationTask: Task<Void, Never>?

    // Paramètres d'état
    public private(set) var mode: Mode = .idle
    public private(set) var playbackState: PlaybackState = .stopped
    public var config: SimulationConfig

    // Métriques du parcours actif
    public private(set) var currentProgress: Double = 0.0
    public private(set) var currentDistanceMeters: Double = 0.0
    public private(set) var totalDistanceMeters: Double = 0.0
    public private(set) var currentCoordinate: CLLocationCoordinate2D?
    public private(set) var currentCourse: Double = 0.0
    public private(set) var elapsedTimeSeconds: Double = 0.0

    public var telemetryStream: AsyncStream<TelemetrySnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: TelemetrySnapshot.self)
        self.continuation = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }
        return stream
    }

    public init(config: SimulationConfig = .standard) {
        self.config = config
    }

    // MARK: - API de Contrôle Statique

    /// Active une simulation sur une position géographique fixe.
    public func setFixedLocation(
        coordinate: CLLocationCoordinate2D,
        altitude: Double? = nil,
        accuracy: Double? = nil
    ) {
        stopLoop()
        mode = .fixed(coordinate)
        playbackState = .playing
        currentCoordinate = coordinate
        currentCourse = 0.0
        currentProgress = 1.0
        currentDistanceMeters = 0.0
        totalDistanceMeters = 0.0
        elapsedTimeSeconds = 0.0

        if let altitude { self.config.altitude = altitude }
        if let accuracy { self.config.horizontalAccuracy = accuracy }

        emitFixedPosition(coordinate)
        startFixedLoop(coordinate)
    }

    // MARK: - API de Contrôle Itinéraire Dynamique

    /// Charge et prépare un parcours de waypoints pour la simulation.
    public func loadRoute(coordinates: [CLLocationCoordinate2D]) {
        stopLoop()
        guard coordinates.count >= 2 else {
            if let single = coordinates.first {
                setFixedLocation(coordinate: single)
            }
            return
        }

        self.mode = .route(coordinates: coordinates)
        self.totalDistanceMeters = GeoMath.totalDistance(of: coordinates)
        self.currentDistanceMeters = 0.0
        self.currentProgress = 0.0
        self.elapsedTimeSeconds = 0.0
        self.playbackState = .stopped
        self.currentCoordinate = coordinates.first
        self.currentCourse = GeoMath.initialBearing(from: coordinates[0], to: coordinates[1])

        emitCurrentInterpolatedSnapshot()
    }

    /// Démarre ou reprend la lecture physique de l'itinéraire.
    public func play() {
        guard case .route(let coordinates) = mode, !coordinates.isEmpty else { return }

        if playbackState == .playing { return }

        // Si on est à la fin et qu'on n'est pas en boucle, on rembobine
        if currentProgress >= 1.0 {
            currentDistanceMeters = 0.0
            currentProgress = 0.0
            elapsedTimeSeconds = 0.0
        }

        playbackState = .playing
        startRouteLoop(coordinates: coordinates)
    }

    /// Met la simulation en pause sans réinitialiser la progression.
    public func pause() {
        guard playbackState == .playing else { return }
        playbackState = .paused
        stopLoop()
        emitCurrentInterpolatedSnapshot(speedOverride: 0.0)
    }

    /// Reprend la simulation si elle était en pause.
    public func resume() {
        if playbackState == .paused {
            play()
        }
    }

    /// Déplace la tête de lecture à un pourcentage précis [0.0, 1.0].
    public func seek(to progress: Double) {
        guard case .route(let coordinates) = mode else { return }
        let clamped = min(max(progress, 0.0), 1.0)
        self.currentProgress = clamped
        self.currentDistanceMeters = clamped * totalDistanceMeters

        if let result = GeoMath.interpolate(along: coordinates, progress: clamped) {
            self.currentCoordinate = result.coordinate
            self.currentCourse = result.course
        }

        emitCurrentInterpolatedSnapshot(speedOverride: playbackState == .playing ? config.speedMetersPerSecond : 0.0)
    }

    public func start() {
        if case .route = mode {
            play()
        } else if case .fixed(let coord) = mode {
            startFixedLoop(coord)
        }
    }

    public func stop() {
        stopLoop()
        playbackState = .stopped
        currentDistanceMeters = 0.0
        currentProgress = 0.0
        elapsedTimeSeconds = 0.0
    }

    // MARK: - Boucles d'Exécution Internes

    private func stopLoop() {
        simulationTask?.cancel()
        simulationTask = nil
    }

    private func startFixedLoop(_ coordinate: CLLocationCoordinate2D) {
        stopLoop()
        simulationTask = Task { [weak self] in
            // Envoi d'une mise à jour périodique à 1 Hz pour rafraîchir l'horodatage ou le micro-bruit
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }
                self.emitFixedPosition(coordinate)
            }
        }
    }

    private func startRouteLoop(coordinates: [CLLocationCoordinate2D]) {
        stopLoop()

        let frequency = max(config.updateFrequencyHz, 1.0)
        let intervalSeconds = 1.0 / frequency
        let intervalNanos = UInt64(intervalSeconds * 1_000_000_000)

        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanos)
                guard let self, !Task.isCancelled else { break }

                let distanceStep = self.config.speedMetersPerSecond * intervalSeconds
                self.currentDistanceMeters += distanceStep
                self.elapsedTimeSeconds += intervalSeconds

                if self.totalDistanceMeters > 0 {
                    self.currentProgress = min(self.currentDistanceMeters / self.totalDistanceMeters, 1.0)
                } else {
                    self.currentProgress = 1.0
                }

                if let result = GeoMath.interpolate(
                    along: coordinates,
                    distanceMeters: self.currentDistanceMeters,
                    totalDistance: self.totalDistanceMeters
                ) {
                    var point = result.coordinate
                    if self.config.addGpsJitter && self.config.jitterRadiusMeters > 0 {
                        point = GeoMath.addGpsJitter(to: point, maxRadiusMeters: self.config.jitterRadiusMeters)
                    }

                    self.currentCoordinate = point
                    self.currentCourse = result.course

                    let snapshot = TelemetrySnapshot(
                        coordinate: point,
                        altitude: self.config.altitude,
                        horizontalAccuracy: self.config.horizontalAccuracy,
                        course: result.course,
                        speed: self.config.speedMetersPerSecond,
                        timestamp: Date(),
                        source: .localSimulation,
                        placeName: nil,
                        country: nil
                    )
                    self.continuation?.yield(snapshot)

                    if result.isCompleted || self.currentProgress >= 1.0 {
                        if self.config.loopRoute {
                            // Répétition en boucle
                            self.currentDistanceMeters = 0.0
                            self.currentProgress = 0.0
                        } else {
                            self.playbackState = .stopped
                            self.stopLoop()
                            break
                        }
                    }
                }
            }
        }
    }

    private func emitFixedPosition(_ baseCoordinate: CLLocationCoordinate2D) {
        var coord = baseCoordinate
        if config.addGpsJitter && config.jitterRadiusMeters > 0 {
            coord = GeoMath.addGpsJitter(to: coord, maxRadiusMeters: config.jitterRadiusMeters)
        }

        let snapshot = TelemetrySnapshot(
            coordinate: coord,
            altitude: config.altitude,
            horizontalAccuracy: config.horizontalAccuracy,
            course: currentCourse,
            speed: 0.0,
            timestamp: Date(),
            source: .localSimulation,
            placeName: nil,
            country: nil
        )
        continuation?.yield(snapshot)
    }

    private func emitCurrentInterpolatedSnapshot(speedOverride: Double? = nil) {
        guard let coord = currentCoordinate else { return }
        let speed = speedOverride ?? (playbackState == .playing ? config.speedMetersPerSecond : 0.0)

        let snapshot = TelemetrySnapshot(
            coordinate: coord,
            altitude: config.altitude,
            horizontalAccuracy: config.horizontalAccuracy,
            course: currentCourse,
            speed: speed,
            timestamp: Date(),
            source: .localSimulation,
            placeName: nil,
            country: nil
        )
        continuation?.yield(snapshot)
    }
}
