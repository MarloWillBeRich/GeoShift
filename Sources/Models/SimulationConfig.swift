import Foundation

/// Profils de vitesse prédéfinis pour la simulation réaliste.
public enum SimulationSpeedPreset: String, CaseIterable, Sendable, Codable, Identifiable {
    case walking = "walk"
    case running = "run"
    case cycling = "cycle"
    case cityDriving = "city_car"
    case highwayDriving = "highway_car"
    case highSpeedTrain = "train"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .walking: return "Marche (5 km/h)"
        case .running: return "Course (12 km/h)"
        case .cycling: return "Vélo (20 km/h)"
        case .cityDriving: return "Voiture Ville (50 km/h)"
        case .highwayDriving: return "Autoroute (110 km/h)"
        case .highSpeedTrain: return "TGV / Train (300 km/h)"
        case .custom: return "Personnalisée"
        }
    }

    public var shortName: String {
        switch self {
        case .walking: return "Marche"
        case .running: return "Course"
        case .cycling: return "Vélo"
        case .cityDriving: return "Ville"
        case .highwayDriving: return "Autoroute"
        case .highSpeedTrain: return "Train"
        case .custom: return "Perso"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .cityDriving: return "car.fill"
        case .highwayDriving: return "car.side.fill"
        case .highSpeedTrain: return "tram.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// Vitesse équivalente en mètres par seconde (m/s).
    public var metersPerSecond: Double {
        switch self {
        case .walking: return 5.0 / 3.6         // ~ 1.39 m/s
        case .running: return 12.0 / 3.6       // ~ 3.33 m/s
        case .cycling: return 20.0 / 3.6       // ~ 5.56 m/s
        case .cityDriving: return 50.0 / 3.6   // ~ 13.89 m/s
        case .highwayDriving: return 110.0 / 3.6 // ~ 30.56 m/s
        case .highSpeedTrain: return 300.0 / 3.6 // ~ 83.33 m/s
        case .custom: return 10.0 / 3.6
        }
    }
}

/// Configuration globale du moteur de simulation télémétrique.
public struct SimulationConfig: Sendable, Codable, Equatable {
    /// Vitesse cible de déplacement en mètres par seconde.
    public var speedMetersPerSecond: Double

    /// Précision horizontale simulée (en mètres).
    public var horizontalAccuracy: Double

    /// Altitude simulée au-dessus du niveau de la mer (en mètres).
    public var altitude: Double

    /// Répétition automatique de l'itinéraire en boucle fermée.
    public var loopRoute: Bool

    /// Activation d'un micro-bruit GPS réaliste pour émuler les imprécisions d'antenne.
    public var addGpsJitter: Bool

    /// Rayon maximal de perturbation (en mètres).
    public var jitterRadiusMeters: Double

    /// Fréquence de rafraîchissement de la boucle physique (en Hertz).
    public var updateFrequencyHz: Double

    public init(
        speedMetersPerSecond: Double = SimulationSpeedPreset.cityDriving.metersPerSecond,
        horizontalAccuracy: Double = 5.0,
        altitude: Double = 35.0,
        loopRoute: Bool = false,
        addGpsJitter: Bool = false,
        jitterRadiusMeters: Double = 2.5,
        updateFrequencyHz: Double = 10.0
    ) {
        self.speedMetersPerSecond = speedMetersPerSecond
        self.horizontalAccuracy = horizontalAccuracy
        self.altitude = altitude
        self.loopRoute = loopRoute
        self.addGpsJitter = addGpsJitter
        self.jitterRadiusMeters = jitterRadiusMeters
        self.updateFrequencyHz = updateFrequencyHz
    }

    /// Configuration par défaut équilibrée pour les tests et la simulation.
    public static let standard = SimulationConfig()
}
