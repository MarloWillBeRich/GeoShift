import Foundation
import SwiftData
import CoreLocation

/// Type d'action consigné dans le journal d'activité de GeoShift.
public enum HistoryActionType: String, Codable, CaseIterable, Sendable {
    case telemetryStarted = "telemetry_started"
    case manualSimulation = "manual_simulation"
    case routeSimulated = "route_simulated"
    case gpxExported = "gpx_exported"
    case favoriteAdded = "favorite_added"
    case searchExecuted = "search_executed"

    public var displayName: String {
        switch self {
        case .telemetryStarted: return "Démarrage Télémétrie"
        case .manualSimulation: return "Simulation Fixe"
        case .routeSimulated: return "Simulation Itinéraire"
        case .gpxExported: return "Export Fichier GPX"
        case .favoriteAdded: return "Favori Enregistré"
        case .searchExecuted: return "Recherche Adresse"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .telemetryStarted: return "location.fill"
        case .manualSimulation: return "mappin.and.ellipse"
        case .routeSimulated: return "figure.walk.motion"
        case .gpxExported: return "square.and.arrow.up.fill"
        case .favoriteAdded: return "star.fill"
        case .searchExecuted: return "magnifyingglass"
        }
    }
}

/// Modèle SwiftData conservant l'historique complet des actions et simulations réalisées.
@Model
public final class HistoryEntry {
    public var id: UUID = UUID()
    public var actionTypeRaw: String = HistoryActionType.manualSimulation.rawValue
    public var title: String = ""
    public var subtitle: String = ""
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    public var timestamp: Date = Date()

    public init(
        id: UUID = UUID(),
        actionType: HistoryActionType,
        title: String,
        subtitle: String = "",
        latitude: Double,
        longitude: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.actionTypeRaw = actionType.rawValue
        self.title = title
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }

    public var actionType: HistoryActionType {
        get { HistoryActionType(rawValue: actionTypeRaw) ?? .manualSimulation }
        set { actionTypeRaw = newValue.rawValue }
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
