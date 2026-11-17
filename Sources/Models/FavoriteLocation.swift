import Foundation
import SwiftData
import CoreLocation

/// Modèle SwiftData représentant un lieu géographique favori sauvegardé par l'utilisateur.
@Model
public final class FavoriteLocation {
    public var id: UUID = UUID()
    public var name: String = ""
    public var notes: String = ""
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    public var altitude: Double = 0.0
    public var createdAt: Date = Date()
    public var category: String = "Général"

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        latitude: Double,
        longitude: Double,
        altitude: Double = 35.0,
        createdAt: Date = Date(),
        category: String = "Général"
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.createdAt = createdAt
        self.category = category
    }

    /// Représentation en coordonnée MapKit / CoreLocation.
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Catégories prédéfinies pour l'organisation UI.
    public static let defaultCategories: [String] = [
        "Général",
        "Domicile",
        "Travail",
        "Test Lab",
        "Voyage",
        "Parcours Sport"
    ]
}
