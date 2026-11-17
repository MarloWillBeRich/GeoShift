import Foundation
import SwiftUI
import MapKit
import Observation
import CoreLocation

/// ViewModel pilotant la vue principale du tableau de bord (carte, caméra, HUD et actions rapides).
@Observable
@MainActor
public final class DashboardViewModel {
    // Caméra MapKit iOS 17
    public var cameraPosition: MapCameraPosition = .automatic

    // Épingles et interactions manuelles
    public var selectedCoordinate: CLLocationCoordinate2D?
    public var isQuickSimulationPresented: Bool = false
    public var isSaveFavoritePresented: Bool = false
    public var isSearchPresented: Bool = false
    public var isTelemetryExpanded: Bool = true

    // Coordonnées pour simulation manuelle rapide
    public var manualLatitudeText: String = ""
    public var manualLongitudeText: String = ""
    public var manualAltitudeText: String = "35.0"
    public var manualAccuracyText: String = "5.0"

    public init() {}

    /// Centre la caméra sur la coordonnée active (qu'elle soit réelle ou simulée).
    public func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
        }
    }

    /// Réception d'un appui prolongé sur la carte pour déposer une épingle de simulation.
    public func handleMapLongPress(at coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        manualLatitudeText = String(format: "%.6f", coordinate.latitude)
        manualLongitudeText = String(format: "%.6f", coordinate.longitude)
        isQuickSimulationPresented = true
    }

    /// Prépare la boîte de dialogue de simulation manuelle.
    public func prepareManualSimulation(initial: CLLocationCoordinate2D) {
        manualLatitudeText = String(format: "%.6f", initial.latitude)
        manualLongitudeText = String(format: "%.6f", initial.longitude)
        isQuickSimulationPresented = true
    }

    /// Réinitialise l'épingle sélectionnée.
    public func clearSelection() {
        selectedCoordinate = nil
    }
}
