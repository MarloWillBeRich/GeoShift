import XCTest
import CoreLocation
@testable import GeoShift

final class GPXExporterTests: XCTestCase {

    func testSingleWaypointXMLGeneration() {
        let coord = CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350)
        let name = "Tour Eiffel & Trocadéro"
        let xml = GPXExporter.generateSingleWaypointGPX(
            coordinate: coord,
            altitude: 45.0,
            name: name
        )

        XCTAssertTrue(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xml.contains("<gpx version=\"1.1\""))
        XCTAssertTrue(xml.contains("http://www.topografix.com/GPX/1/1"))
        XCTAssertTrue(xml.contains("lat=\"48.858844\" lon=\"2.294350\""))
        XCTAssertTrue(xml.contains("<ele>45.0</ele>"))
        XCTAssertTrue(xml.contains("<name>Tour Eiffel &amp; Trocadéro</name>"))
        XCTAssertTrue(xml.contains("<time>"))
    }

    func testRouteGPXXMLGenerationWithSequentialTiming() {
        let coords = [
            CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350),
            CLLocationCoordinate2D(latitude: 48.865633, longitude: 2.321236),
            CLLocationCoordinate2D(latitude: 48.860611, longitude: 2.337644)
        ]

        let xml = GPXExporter.generateRouteGPX(
            name: "Parcours Test",
            coordinates: coords,
            speedMetersPerSecond: 13.89, // 50 km/h
            altitude: 35.0
        )

        XCTAssertTrue(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xml.contains("<name>Parcours Test</name>"))

        // Doit contenir 3 balises <wpt> avec des <name>P1</name>, P2, P3 pour Xcode
        XCTAssertTrue(xml.contains("<name>P1</name>"))
        XCTAssertTrue(xml.contains("<name>P2</name>"))
        XCTAssertTrue(xml.contains("<name>P3</name>"))

        // Doit contenir la structure <trk><trkseg><trkpt>
        XCTAssertTrue(xml.contains("<trk>"))
        XCTAssertTrue(xml.contains("<trkseg>"))
        XCTAssertTrue(xml.contains("<trkpt"))
        XCTAssertTrue(xml.contains("</trkseg>"))
        XCTAssertTrue(xml.contains("</trk>"))
    }

    func testTemporaryFileCreation() {
        let sampleContent = "<gpx>Sample Test Content</gpx>"
        let tempURL = GPXExporter.createTemporaryGPXFile(content: sampleContent, filename: "test_export")

        XCTAssertNotNil(tempURL)
        XCTAssertTrue(tempURL!.path.hasSuffix(".gpx"))

        let readBack = try? String(contentsOf: tempURL!, encoding: .utf8)
        XCTAssertEqual(readBack, sampleContent)

        // Nettoyage
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    func testSaveToDocumentsDirectory() {
        let sampleContent = "<gpx>Document Test Content</gpx>"
        let docURL = GPXExporter.saveToDocumentsDirectory(content: sampleContent, filename: "doc_test_export")

        XCTAssertNotNil(docURL)
        XCTAssertTrue(docURL!.path.hasSuffix(".gpx"))

        let readBack = try? String(contentsOf: docURL!, encoding: .utf8)
        XCTAssertEqual(readBack, sampleContent)

        // Nettoyage
        if let docURL {
            try? FileManager.default.removeItem(at: docURL)
        }
    }
}
