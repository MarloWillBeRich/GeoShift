import Foundation
import CoreLocation

/// Fournisseur de télémétrie encapsulant le capteur GPS physique via CLLocationManager.
@MainActor
public final class RealLocationProvider: NSObject, CLLocationManagerDelegate, LocationProviderProtocol {
    private let locationManager: CLLocationManager
    private var continuation: AsyncStream<TelemetrySnapshot>.Continuation?
    private var isRunning: Bool = false

    /// Statut d'autorisation actuel exposé de façon réactive.
    public private(set) var authorizationStatus: CLAuthorizationStatus

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

    public override init() {
        self.locationManager = CLLocationManager()
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.distanceFilter = kCLDistanceFilterNone
        self.locationManager.activityType = .otherNavigation
    }

    /// Sollicite l'autorisation d'accès au GPS en premier plan.
    public func requestAuthorization() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        requestAuthorization()

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            if isRunning {
                manager.startUpdatingLocation()
                manager.startUpdatingHeading()
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            // Émission éventuelle d'une notification ou continuation
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let snapshot = TelemetrySnapshot(
            coordinate: location.coordinate,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            course: location.course >= 0.0 ? location.course : 0.0,
            speed: location.speed >= 0.0 ? location.speed : 0.0,
            timestamp: location.timestamp,
            source: .realHardware,
            placeName: nil,
            country: nil
        )

        continuation?.yield(snapshot)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Le cap magnétique ou vrai cap peut enrichir la prochaine position
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Gestion silencieuse ou journalisation sans planter le flux
    }
}
