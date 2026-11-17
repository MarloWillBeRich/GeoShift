import Foundation
import CoreLocation

/// Exportateur de fichiers GPX 1.1 standardisé, optimisé pour le moteur de simulation Xcode d'Apple.
public enum GPXExporter {

    // MARK: - Génération de XML GPX

    /// Génère le contenu XML GPX 1.1 pour un point unique ou favori.
    public static func generateSingleWaypointGPX(
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 35.0,
        name: String = "GeoShift Waypoint",
        timestamp: Date = Date()
    ) -> String {
        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timeString = isoDateFormatter.string(from: timestamp)

        let safeName = escapeXML(name)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GeoShift iOS (Apple Xcode Compatible)"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
            <metadata>
                <name>\(safeName)</name>
                <time>\(timeString)</time>
            </metadata>
            <wpt lat="\(String(format: "%.6f", coordinate.latitude))" lon="\(String(format: "%.6f", coordinate.longitude))">
                <ele>\(String(format: "%.1f", altitude))</ele>
                <time>\(timeString)</time>
                <name>\(safeName)</name>
            </wpt>
        </gpx>
        """
    }

    /// Génère un fichier GPX 1.1 complet pour un itinéraire avec horodatage séquentiel précis.
    /// Xcode utilise les balises `<wpt>` séquentielles avec `<time>` pour animer la position en direct.
    public static func generateRouteGPX(
        name: String,
        coordinates: [CLLocationCoordinate2D],
        speedMetersPerSecond: Double = SimulationSpeedPreset.cityDriving.metersPerSecond,
        altitude: Double = 35.0,
        startDate: Date = Date()
    ) -> String {
        guard !coordinates.isEmpty else {
            return generateSingleWaypointGPX(
                coordinate: CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350),
                altitude: altitude,
                name: name,
                timestamp: startDate
            )
        }

        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        let safeSpeed = max(speedMetersPerSecond, 0.5)
        let safeName = escapeXML(name)

        var currentTime = startDate
        var waypointsXML = ""
        var trackPointsXML = ""

        for i in 0..<coordinates.count {
            let coord = coordinates[i]

            if i > 0 {
                let prevCoord = coordinates[i - 1]
                let segmentDistance = GeoMath.haversineDistance(from: prevCoord, to: coord)
                let deltaSeconds = segmentDistance / safeSpeed
                currentTime = currentTime.addingTimeInterval(deltaSeconds)
            }

            let timeString = isoDateFormatter.string(from: currentTime)
            let latStr = String(format: "%.6f", coord.latitude)
            let lonStr = String(format: "%.6f", coord.longitude)
            let eleStr = String(format: "%.1f", altitude)

            // Balise <wpt> pour la compatibilité avec le simulateur Xcode
            waypointsXML += """
                <wpt lat="\(latStr)" lon="\(lonStr)">
                    <ele>\(eleStr)</ele>
                    <time>\(timeString)</time>
                    <name>P\(i + 1)</name>
                </wpt>\n
            """

            // Balise <trkpt> pour la compatibilité SIG et applications tierces
            trackPointsXML += """
                    <trkpt lat="\(latStr)" lon="\(lonStr)">
                        <ele>\(eleStr)</ele>
                        <time>\(timeString)</time>
                    </trkpt>\n
            """
        }

        let initialTimeString = isoDateFormatter.string(from: startDate)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GeoShift iOS (Apple Xcode Compatible)"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
            <metadata>
                <name>\(safeName)</name>
                <time>\(initialTimeString)</time>
            </metadata>
        \(waypointsXML)
            <trk>
                <name>\(safeName)</name>
                <trkseg>
        \(trackPointsXML)        </trkseg>
            </trk>
        </gpx>
        """
    }

    // MARK: - Écriture Fichier & Partage (Compatible App Fichiers iOS)

    /// Écrit le fichier GPX directement dans le dossier Documents de l'application (visible dans l'application Fichiers iOS).
    @discardableResult
    public static func saveToDocumentsDirectory(content: String, filename: String = "route") -> URL? {
        let cleanFilename = filename
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let finalFilename = cleanFilename.hasSuffix(".gpx") ? cleanFilename : "\(cleanFilename).gpx"

        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = docsDir.appendingPathComponent(finalFilename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Écrit le contenu GPX dans un fichier temporaire prêt pour `ShareLink` ou `UIActivityViewController`
    /// et l'enregistre simultanément dans le dossier partagé Documents.
    public static func createTemporaryGPXFile(content: String, filename: String = "route") -> URL? {
        // Enregistrement miroir dans Documents pour visibilité dans l'app Fichiers (UIFileSharingEnabled)
        _ = saveToDocumentsDirectory(content: content, filename: filename)

        let cleanFilename = filename
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let finalFilename = cleanFilename.hasSuffix(".gpx") ? cleanFilename : "\(cleanFilename).gpx"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(finalFilename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Échappement XML

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
