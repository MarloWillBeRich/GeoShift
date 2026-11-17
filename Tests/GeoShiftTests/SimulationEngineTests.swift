import XCTest
import CoreLocation
@testable import GeoShift

@MainActor
final class SimulationEngineTests: XCTestCase {

    func testInitialState() {
        let provider = SimulatedLocationProvider()
        XCTAssertEqual(provider.mode, .idle)
        XCTAssertEqual(provider.playbackState, .stopped)
        XCTAssertEqual(provider.currentProgress, 0.0)
        XCTAssertEqual(provider.currentDistanceMeters, 0.0)
    }

    func testSetFixedLocation() {
        let provider = SimulatedLocationProvider()
        let coord = CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350)

        provider.setFixedLocation(coordinate: coord, altitude: 42.0, accuracy: 3.0)

        XCTAssertEqual(provider.mode, .fixed(coord))
        XCTAssertEqual(provider.playbackState, .playing)
        XCTAssertEqual(provider.currentCoordinate?.latitude, coord.latitude)
        XCTAssertEqual(provider.currentCoordinate?.longitude, coord.longitude)
        XCTAssertEqual(provider.config.altitude, 42.0)
        XCTAssertEqual(provider.config.horizontalAccuracy, 3.0)

        provider.stop()
        XCTAssertEqual(provider.playbackState, .stopped)
    }

    func testLoadRoute() {
        let provider = SimulatedLocationProvider()
        let p1 = CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350)
        let p2 = CLLocationCoordinate2D(latitude: 48.860611, longitude: 2.337644)
        let coords = [p1, p2]

        provider.loadRoute(coordinates: coords)

        XCTAssertEqual(provider.mode, .route(coordinates: coords))
        XCTAssertEqual(provider.playbackState, .stopped)
        XCTAssertGreaterThan(provider.totalDistanceMeters, 3000.0)
        XCTAssertEqual(provider.currentProgress, 0.0)
        XCTAssertEqual(provider.currentCoordinate?.latitude, p1.latitude)
    }

    func testSeek() {
        let provider = SimulatedLocationProvider()
        let p1 = CLLocationCoordinate2D(latitude: 48.0, longitude: 2.0)
        let p2 = CLLocationCoordinate2D(latitude: 49.0, longitude: 2.0)
        let coords = [p1, p2]

        provider.loadRoute(coordinates: coords)
        provider.seek(to: 0.5)

        XCTAssertEqual(provider.currentProgress, 0.5, accuracy: 1e-4)
        XCTAssertEqual(provider.currentDistanceMeters, provider.totalDistanceMeters * 0.5, accuracy: 1.0)
        XCTAssertNotNil(provider.currentCoordinate)
    }

    func testPlayPauseResume() {
        let provider = SimulatedLocationProvider()
        let p1 = CLLocationCoordinate2D(latitude: 48.0, longitude: 2.0)
        let p2 = CLLocationCoordinate2D(latitude: 49.0, longitude: 2.0)

        provider.loadRoute(coordinates: [p1, p2])
        XCTAssertEqual(provider.playbackState, .stopped)

        provider.play()
        XCTAssertEqual(provider.playbackState, .playing)

        provider.pause()
        XCTAssertEqual(provider.playbackState, .paused)

        provider.resume()
        XCTAssertEqual(provider.playbackState, .playing)

        provider.stop()
        XCTAssertEqual(provider.playbackState, .stopped)
    }
}
