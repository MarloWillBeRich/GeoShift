import Foundation
import SwiftUI
import Observation
import CoreLocation

/// Onglets de navigation principale de GeoShift.
public enum TabIdentifier: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case routes = "routes"
    case favorites = "favorites"
    case history = "history"
    case settings = "settings"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Carte"
        case .routes: return "Itinéraires"
        case .favorites: return "Favoris"
        case .history: return "Historique"
        case .settings: return "Réglages"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .dashboard: return "map.fill"
        case .routes: return "point.topleft.down.to.point.bottomright.curvepath"
        case .favorites: return "star.fill"
        case .history: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Style visuel de rendu de la carte MapKit.
public enum AppMapStyle: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case hybrid = "Hybride"
    case satellite = "Satellite"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .standard: return "map"
        case .hybrid: return "square.2.layers.3d"
        case .satellite: return "globe.europe.africa.fill"
        }
    }
}

/// État global réactif de l'application GeoShift injecté dans l'environnement SwiftUI.
@Observable
@MainActor
public final class AppState {
    // Navigation
    public var selectedTab: TabIdentifier = .dashboard

    // Moteur télémétrique partagé
    public let locationEngine: LocationEngine

    // Préférences utilisateur
    public var isMetric: Bool = true
    public var hapticsEnabled: Bool = true
    public var autoCenterMap: Bool = true
    public var mapStyle: AppMapStyle = .standard

    // Notifications toast éphémères
    public var toastMessage: String?
    private var toastDismissTask: Task<Void, Never>?

    public init(locationEngine: LocationEngine = LocationEngine()) {
        self.locationEngine = locationEngine
    }

    /// Déclenche un retour haptique système si activé.
    public func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Affiche une bannière informative éphémère.
    public func showToast(_ message: String) {
        toastDismissTask?.cancel()
        toastMessage = message
        triggerHapticFeedback(.light)

        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            self.toastMessage = nil
        }
    }

    /// Bascule vers le tableau de bord et simule la coordonnée sélectionnée.
    public func startSimulation(
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 35.0,
        accuracy: Double = 5.0,
        name: String? = nil
    ) {
        locationEngine.simulateFixedCoordinate(coordinate, altitude: altitude, accuracy: accuracy)
        selectedTab = .dashboard
        showToast("Simulation activée : \(name ?? CoordinateFormatter.formatCompact(coordinate))")
    }

    /// Repasse immédiatement sur le signal GPS physique réel.
    public func restoreRealGPS() {
        locationEngine.startRealHardware()
        showToast("Signal GPS matériel rétabli")
    }
}
