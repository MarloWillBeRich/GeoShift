import Foundation
import SwiftData
import CoreLocation

/// Représentation immuable et sérialisable d'un jalon ou waypoint d'itinéraire.
public struct RouteWaypoint: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        altitude: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public static func == (lhs: RouteWaypoint, rhs: RouteWaypoint) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        abs(lhs.latitude - rhs.latitude) < 1e-7 &&
        abs(lhs.longitude - rhs.longitude) < 1e-7 &&
        abs(lhs.altitude - rhs.altitude) < 1e-2
    }
}

/// Modèle SwiftData représentant un itinéraire sauvegardé complet avec ses coordonnées et ses métadonnées.
@Model
public final class SavedRoute {
    public var id: UUID = UUID()
    public var name: String = ""
    public var waypointsData: Data = Data()
    public var distanceMeters: Double = 0.0
    public var expectedDurationSeconds: Double = 0.0
    public var createdAt: Date = Date()
    public var transportTypeRawValue: String = "automobile"

    public init(
        id: UUID = UUID(),
        name: String,
        waypoints: [RouteWaypoint],
        distanceMeters: Double,
        expectedDurationSeconds: Double,
        createdAt: Date = Date(),
        transportTypeRawValue: String = "automobile"
    ) {
        self.id = id
        self.name = name
        self.distanceMeters = distanceMeters
        self.expectedDurationSeconds = expectedDurationSeconds
        self.createdAt = createdAt
        self.transportTypeRawValue = transportTypeRawValue
        let encoder = JSONEncoder()
        self.waypointsData = (try? encoder.encode(waypoints)) ?? Data()
    }

    /// Décode et ré-encode les waypoints de façon transparente depuis la propriété binaire.
    public var waypoints: [RouteWaypoint] {
        get {
            guard !waypointsData.isEmpty else { return [] }
            let decoder = JSONDecoder()
            return (try? decoder.decode([RouteWaypoint].self, from: waypointsData)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            waypointsData = (try? encoder.encode(newValue)) ?? Data()
        }
    }

    /// Extrait la liste ordonnée des coordonnées géographiques des waypoints.
    public var coordinates: [CLLocationCoordinate2D] {
        waypoints.map { $0.coordinate }
    }
}
