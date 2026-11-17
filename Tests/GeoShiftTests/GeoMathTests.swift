import XCTest
import CoreLocation
@testable import GeoShift

final class GeoMathTests: XCTestCase {

    // Coordonnées de référence
    let eiffelTower = CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350)
    let louvreMuseum = CLLocationCoordinate2D(latitude: 48.860611, longitude: 2.337644)
    let northPole = CLLocationCoordinate2D(latitude: 90.0, longitude: 0.0)
    let equatorOrigin = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)

    // MARK: - Tests de Validation

    func testCoordinateValidation() {
        XCTAssertTrue(GeoMath.isValidCoordinate(latitude: 48.858844, longitude: 2.294350))
        XCTAssertTrue(GeoMath.isValidCoordinate(latitude: -90.0, longitude: 180.0))
        XCTAssertTrue(GeoMath.isValidCoordinate(latitude: 0.0, longitude: 0.0))

        XCTAssertFalse(GeoMath.isValidCoordinate(latitude: 91.0, longitude: 2.0))
        XCTAssertFalse(GeoMath.isValidCoordinate(latitude: -90.1, longitude: 0.0))
        XCTAssertFalse(GeoMath.isValidCoordinate(latitude: 45.0, longitude: 181.0))
        XCTAssertFalse(GeoMath.isValidCoordinate(latitude: 45.0, longitude: -180.5))
        XCTAssertFalse(GeoMath.isValidCoordinate(latitude: .nan, longitude: 0.0))
        XCTAssertFalse(GeoMath.isValidCoordinate(latitude: 0.0, longitude: .infinity))
    }

    func testCoordinateClamping() {
        let clamped1 = GeoMath.clampCoordinate(latitude: 95.0, longitude: 200.0)
        XCTAssertEqual(clamped1.latitude, 90.0)
        XCTAssertEqual(clamped1.longitude, -160.0, accuracy: 1e-4)

        let clamped2 = GeoMath.clampCoordinate(latitude: -100.0, longitude: -190.0)
        XCTAssertEqual(clamped2.latitude, -90.0)
        XCTAssertEqual(clamped2.longitude, 170.0, accuracy: 1e-4)
    }

    // MARK: - Tests Distance de Haversine

    func testHaversineSamePoint() {
        let dist = GeoMath.haversineDistance(from: eiffelTower, to: eiffelTower)
        XCTAssertEqual(dist, 0.0, accuracy: 1e-5)
    }

    func testHaversineKnownDistance() {
        // Distance orthodromique entre Tour Eiffel et Musée du Louvre : ~3170 mètres
        let dist = GeoMath.haversineDistance(from: eiffelTower, to: louvreMuseum)
        XCTAssertGreaterThan(dist, 3100.0)
        XCTAssertLessThan(dist, 3250.0)
    }

    // MARK: - Tests Calcul du Cap (Bearing)

    func testInitialBearingCardinalDirections() {
        let pStart = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let pNorth = CLLocationCoordinate2D(latitude: 1.0, longitude: 0.0)
        let pEast = CLLocationCoordinate2D(latitude: 0.0, longitude: 1.0)
        let pSouth = CLLocationCoordinate2D(latitude: -1.0, longitude: 0.0)
        let pWest = CLLocationCoordinate2D(latitude: 0.0, longitude: -1.0)

        let bearingN = GeoMath.initialBearing(from: pStart, to: pNorth)
        XCTAssertEqual(bearingN, 0.0, accuracy: 0.1)

        let bearingE = GeoMath.initialBearing(from: pStart, to: pEast)
        XCTAssertEqual(bearingE, 90.0, accuracy: 0.1)

        let bearingS = GeoMath.initialBearing(from: pStart, to: pSouth)
        XCTAssertEqual(bearingS, 180.0, accuracy: 0.1)

        let bearingW = GeoMath.initialBearing(from: pStart, to: pWest)
        XCTAssertEqual(bearingW, 270.0, accuracy: 0.1)
    }

    // MARK: - Tests Destination Coordinate

    func testDestinationCoordinate() {
        let start = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let distance: Double = 111_319.0 // Environ 1 degré à l'équateur
        let dest = GeoMath.destinationCoordinate(from: start, distanceMeters: distance, bearingDegrees: 0.0)

        XCTAssertEqual(dest.latitude, 1.0, accuracy: 0.01)
        XCTAssertEqual(dest.longitude, 0.0, accuracy: 0.01)
    }

    // MARK: - Tests Interpolation de Polyligne

    func testPolylineInterpolation() {
        let p1 = CLLocationCoordinate2D(latitude: 48.0, longitude: 2.0)
        let p2 = CLLocationCoordinate2D(latitude: 49.0, longitude: 2.0)
        let coords = [p1, p2]

        let total = GeoMath.totalDistance(of: coords)
        XCTAssertGreaterThan(total, 110_000.0)

        // Interpolation à 0%
        let resStart = GeoMath.interpolate(along: coords, progress: 0.0)
        XCTAssertNotNil(resStart)
        XCTAssertEqual(resStart!.coordinate.latitude, 48.0, accuracy: 1e-4)
        XCTAssertEqual(resStart!.progress, 0.0, accuracy: 1e-4)
        XCTAssertFalse(resStart!.isCompleted)

        // Interpolation à 50%
        let resMid = GeoMath.interpolate(along: coords, progress: 0.5)
        XCTAssertNotNil(resMid)
        XCTAssertEqual(resMid!.coordinate.latitude, 48.5, accuracy: 0.05)
        XCTAssertEqual(resMid!.progress, 0.5, accuracy: 1e-2)

        // Interpolation à 100%
        let resEnd = GeoMath.interpolate(along: coords, progress: 1.0)
        XCTAssertNotNil(resEnd)
        XCTAssertEqual(resEnd!.coordinate.latitude, 49.0, accuracy: 1e-4)
        XCTAssertTrue(resEnd!.isCompleted)
    }

    // MARK: - Tests GPS Jitter

    func testGpsJitterStaysWithinMaxRadius() {
        let base = CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350)
        let maxRadius: Double = 5.0

        for _ in 0..<50 {
            let jittered = GeoMath.addGpsJitter(to: base, maxRadiusMeters: maxRadius)
            let distance = GeoMath.haversineDistance(from: base, to: jittered)
            XCTAssertLessThanOrEqual(distance, maxRadius + 0.01)
        }
    }
}
