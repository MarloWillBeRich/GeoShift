import XCTest
import CoreLocation
@testable import GeoShift

@MainActor
final class LocationWorkflowIntegrationTests: XCTestCase {

    // MARK: - 1. Test Démarrage & Initialisation

    func testLaunchAndInitialState() {
        let engine = LocationEngine()
        XCTAssertEqual(engine.activeSource, .realHardware)
        XCTAssertFalse(engine.isSimulating)
        XCTAssertEqual(engine.simulationPlaybackState, .stopped)

        let snapshot = engine.currentSnapshot
        XCTAssertEqual(snapshot.source, .realHardware)
        XCTAssertTrue(snapshot.coordinate.latitude > 0.0)
        XCTAssertTrue(snapshot.coordinate.longitude > 0.0)
    }

    // MARK: - 2. Test Recherche d'Adresses & Détection Coordonnées

    func testAddressSearchCoordinateParsing() {
        // Test parsing direct de coordonnées utilisateur
        let validInputs = [
            "48.858844, 2.294350",
            "48.858844 2.294350",
            "48.858844,2.294350",
            "  48.858844 ,  2.294350  "
        ]

        for input in validInputs {
            let parsed = CoordinateFormatter.parseCoordinate(from: input)
            XCTAssertNotNil(parsed, "Échec du parsing pour l'entrée: \(input)")
            if let parsed {
                XCTAssertEqual(parsed.latitude, 48.858844, accuracy: 1e-4)
                XCTAssertEqual(parsed.longitude, 2.294350, accuracy: 1e-4)
            }
        }

        // Test coordonnées invalides
        let invalidInputs = [
            "95.0, 2.0",
            "-95.0, 2.0",
            "48.0, 195.0",
            "abc, def",
            ""
        ]

        for input in invalidInputs {
            let parsed = CoordinateFormatter.parseCoordinate(from: input)
            XCTAssertNil(parsed, "Ne devrait pas parser: \(input)")
        }
    }

    // MARK: - 3. Test Simulation Locale Fixe

    func testLocalFixedSimulation() {
        let engine = LocationEngine()
        let targetCoord = CLLocationCoordinate2D(latitude: 48.860611, longitude: 2.337644) // Musée du Louvre

        engine.simulateFixedCoordinate(targetCoord, altitude: 38.0, accuracy: 3.5)

        XCTAssertTrue(engine.isSimulating)
        XCTAssertEqual(engine.activeSource, .localSimulation)

        let snapshot = engine.currentSnapshot
        XCTAssertEqual(snapshot.source, .localSimulation)
        XCTAssertEqual(snapshot.coordinate.latitude, targetCoord.latitude, accuracy: 1e-5)
        XCTAssertEqual(snapshot.coordinate.longitude, targetCoord.longitude, accuracy: 1e-5)
        XCTAssertEqual(snapshot.altitude, 38.0, accuracy: 0.1)
        XCTAssertEqual(snapshot.horizontalAccuracy, 3.5, accuracy: 0.1)
    }

    // MARK: - 4. Test Simulation Itinéraire avec Cinématique

    func testRouteSimulationLifecycle() {
        let engine = LocationEngine()
        let p1 = CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350) // Tour Eiffel
        let p2 = CLLocationCoordinate2D(latitude: 48.860611, longitude: 2.337644) // Louvre
        let coords = [p1, p2]

        let config = SimulationConfig(
            speedPreset: .cycling, // ~20 km/h
            altitude: 35.0,
            horizontalAccuracy: 4.0,
            simulatedCourse: 65.0,
            loopRoute: false
        )

        engine.simulateRoute(coordinates: coords, config: config)

        XCTAssertTrue(engine.isSimulating)
        XCTAssertEqual(engine.simulationPlaybackState, .playing)
        XCTAssertGreaterThan(engine.simulationTotalDistance, 3000.0)

        // Test Pause
        engine.pauseSimulation()
        XCTAssertEqual(engine.simulationPlaybackState, .paused)

        // Test Reprise
        engine.resumeSimulation()
        XCTAssertEqual(engine.simulationPlaybackState, .playing)

        // Test Arrêt
        engine.stopSimulation()
        XCTAssertEqual(engine.simulationPlaybackState, .stopped)
    }

    // MARK: - 5. Test Retour au GPS Réel

    func testRestoreRealHardwareGPS() {
        let engine = LocationEngine()
        let dummyCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060) // New York

        // 1. Activer la simulation
        engine.simulateFixedCoordinate(dummyCoord)
        XCTAssertTrue(engine.isSimulating)
        XCTAssertEqual(engine.activeSource, .localSimulation)

        // 2. Restaurer le GPS réel
        engine.startRealHardware()
        XCTAssertFalse(engine.isSimulating)
        XCTAssertEqual(engine.activeSource, .realHardware)
        XCTAssertEqual(engine.simulationPlaybackState, .stopped)
    }

    // MARK: - 6. Test Pipeline Export GPX

    func testGPXExportPipeline() {
        let p1 = CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350)
        let p2 = CLLocationCoordinate2D(latitude: 48.860611, longitude: 2.337644)
        let coords = [p1, p2]

        let xml = GPXExporter.generateRouteGPX(
            name: "Test Itinéraire Xcode",
            coordinates: coords,
            speedMetersPerSecond: 10.0,
            altitude: 35.0
        )

        XCTAssertTrue(xml.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xml.contains("<gpx version=\"1.1\""))
        XCTAssertTrue(xml.contains("http://www.topografix.com/GPX/1/1"))
        XCTAssertTrue(xml.contains("<wpt lat=\"48.858844\" lon=\"2.294350\">"))
        XCTAssertTrue(xml.contains("<name>Test Itinéraire Xcode</name>"))
    }

    // MARK: - 7. Test de Stabilité (Stress Test 500 Cycles)

    func testStabilityAndStressCycles() {
        let engine = LocationEngine()
        let waypoints = [
            CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350),
            CLLocationCoordinate2D(latitude: 48.860120, longitude: 2.297500),
            CLLocationCoordinate2D(latitude: 48.862300, longitude: 2.302100),
            CLLocationCoordinate2D(latitude: 48.863800, longitude: 2.306200)
        ]

        // 500 commutations rapides et modifications de coordonnées pour vérifier l'absence de fuite ou de deadlock
        for i in 0..<500 {
            let coord = waypoints[i % waypoints.count]
            if i % 2 == 0 {
                engine.simulateFixedCoordinate(coord)
            } else {
                engine.seekSimulation(to: Double(i % 100) / 100.0)
            }
        }

        // L'état final doit être stable
        XCTAssertTrue(engine.isSimulating)
        engine.startRealHardware()
        XCTAssertFalse(engine.isSimulating)
    }
}
