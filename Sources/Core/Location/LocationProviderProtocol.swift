import Foundation
import CoreLocation

/// Source d'acquisition de la télémétrie de position.
public enum TelemetrySource: String, Sendable, Codable, Equatable {
    case realHardware = "MATÉRIEL (GPS Réel)"
    case localSimulation = "SIMULATION LOCALE (Sandbox)"

    public var isSimulation: Bool {
        self == .localSimulation
    }

    public var badgeColorHex: String {
        switch self {
        case .realHardware: return "#35D49A"      // Vert menthe statut normal
        case .localSimulation: return "#48A9FF"   // Bleu néon simulation
        }
    }
}

/// Instantané immuable et thread-safe contenant l'ensemble des grandeurs télémétriques.
public struct TelemetrySnapshot: Sendable, Equatable {
    public let coordinate: CLLocationCoordinate2D
    public let altitude: Double
    public let horizontalAccuracy: Double
    public let course: Double
    public let speed: Double
    public let timestamp: Date
    public let source: TelemetrySource
    public let placeName: String?
    public let country: String?

    public init(
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 0.0,
        horizontalAccuracy: Double = 5.0,
        course: Double = -1.0,
        speed: Double = 0.0,
        timestamp: Date = Date(),
        source: TelemetrySource,
        placeName: String? = nil,
        country: String? = nil
    ) {
        self.coordinate = coordinate
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.course = course
        self.speed = speed
        self.timestamp = timestamp
        self.source = source
        self.placeName = placeName
        self.country = country
    }

    /// Indique si la position se déplace activement (vitesse supérieure à 0.2 m/s).
    public var isMoving: Bool {
        speed > 0.2
    }

    public static func == (lhs: TelemetrySnapshot, rhs: TelemetrySnapshot) -> Bool {
        abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < 1e-7 &&
        abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < 1e-7 &&
        abs(lhs.altitude - rhs.altitude) < 1e-2 &&
        abs(lhs.horizontalAccuracy - rhs.horizontalAccuracy) < 1e-2 &&
        abs(lhs.course - rhs.course) < 1e-2 &&
        abs(lhs.speed - rhs.speed) < 1e-2 &&
        lhs.source == rhs.source &&
        lhs.placeName == rhs.placeName &&
        lhs.country == rhs.country
    }
}

/// Protocole unifié pour les fournisseurs de télémétrie matériels et simulés.
public protocol LocationProviderProtocol: AnyObject, Sendable {
    /// Flux asynchrone émettant les instantanés télémétriques continus.
    var telemetryStream: AsyncStream<TelemetrySnapshot> { get }

    /// Démarre le fournisseur de localisation.
    func start() async

    /// Arrête le flux et libère les ressources matérielles ou timers.
    func stop() async
}
