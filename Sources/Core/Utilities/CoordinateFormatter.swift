import Foundation
import CoreLocation

/// Utilitaires de formatage et d'analyse bidirectionnelle des coordonnées et grandeurs télémétriques.
public enum CoordinateFormatter {

    // MARK: - Formatage Coordonnées Décimales

    /// Formate une coordonnée en notation décimale précise avec orientation cardinale (ex: 48.858844° N, 2.294350° E).
    public static func formatDecimalWithHemisphere(
        latitude: Double,
        longitude: Double,
        fractionDigits: Int = 6
    ) -> (latitude: String, longitude: String) {
        let latCardinal = latitude >= 0.0 ? "N" : "S"
        let lonCardinal = longitude >= 0.0 ? "E" : "W"

        let latVal = String(format: "%0.\(fractionDigits)f° %@", abs(latitude), latCardinal)
        let lonVal = String(format: "%0.\(fractionDigits)f° %@", abs(longitude), lonCardinal)

        return (latVal, lonVal)
    }

    /// Formate en chaîne compacte simple `lat, lon` (ex: `48.858844, 2.294350`).
    public static func formatCompact(
        _ coordinate: CLLocationCoordinate2D,
        fractionDigits: Int = 6
    ) -> String {
        let formatString = "%0.\(fractionDigits)f, %0.\(fractionDigits)f"
        return String(format: formatString, coordinate.latitude, coordinate.longitude)
    }

    // MARK: - Formatage Degrés Minutes Secondes (DMS)

    /// Convertit une valeur décimale de degré en composants Degrés, Minutes, Secondes.
    public static func toDMS(degrees: Double) -> (degrees: Int, minutes: Int, seconds: Double) {
        let absolute = abs(degrees)
        let deg = Int(absolute)
        let remainderMinutes = (absolute - Double(deg)) * 60.0
        let min = Int(remainderMinutes)
        let sec = (remainderMinutes - Double(min)) * 60.0
        return (deg, min, sec)
    }

    /// Formate une coordonnée complète en chaîne DMS (ex: `48° 51' 31.8" N, 2° 17' 39.7" E`).
    public static func formatDMS(_ coordinate: CLLocationCoordinate2D) -> String {
        let (latDeg, latMin, latSec) = toDMS(degrees: coordinate.latitude)
        let (lonDeg, lonMin, lonSec) = toDMS(degrees: coordinate.longitude)

        let latCard = coordinate.latitude >= 0.0 ? "N" : "S"
        let lonCard = coordinate.longitude >= 0.0 ? "E" : "W"

        let latStr = String(format: "%d° %02d' %04.1f\" %@", latDeg, latMin, latSec, latCard)
        let lonStr = String(format: "%d° %02d' %04.1f\" %@", lonDeg, lonMin, lonSec, lonCard)

        return "\(latStr), \(lonStr)"
    }

    // MARK: - Analyse (Parsing) de texte vers coordonnées

    /// Tente d'extraire une `CLLocationCoordinate2D` valide depuis une chaîne utilisateur (décimale ou DMS).
    public static func parseCoordinate(from text: String) -> CLLocationCoordinate2D? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. Essai décimal standard avec séparateur virgule ou espace ou point-virgule
        let separators = CharacterSet(charactersIn: ",; \t")
        let components = trimmed.components(separatedBy: separators).filter { !$0.isEmpty }

        if components.count == 2 {
            if let lat = parseSingleDegree(components[0]),
               let lon = parseSingleDegree(components[1]),
               GeoMath.isValidCoordinate(latitude: lat, longitude: lon) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        // 2. Essai analyse DMS textuelle
        if let dmsParsed = parseDMSString(trimmed),
           GeoMath.isValidCoordinate(dmsParsed) {
            return dmsParsed
        }

        return nil
    }

    private static func parseSingleDegree(_ string: String) -> Double? {
        var clean = string.replacingOccurrences(of: "°", with: "")
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        var multiplier = 1.0
        if clean.uppercased().hasSuffix("S") || clean.uppercased().hasSuffix("W") {
            multiplier = -1.0
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if clean.uppercased().hasSuffix("N") || clean.uppercased().hasSuffix("E") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if clean.uppercased().hasPrefix("S") || clean.uppercased().hasPrefix("W") {
            multiplier = -1.0
            clean = String(clean.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if clean.uppercased().hasPrefix("N") || clean.uppercased().hasPrefix("E") {
            clean = String(clean.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let val = Double(clean) else { return nil }
        return val * multiplier
    }

    private static func parseDMSString(_ string: String) -> CLLocationCoordinate2D? {
        // Détection de motifs du type : 48°51'31.8"N 2°17'39.7"E ou séparés par virgule
        let pattern = #"([0-9]+)[°\s]+([0-9]+)['\s]+([0-9]+(?:\.[0-9]+)?)["\s]*([NSEWnsew])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        let nsString = string as NSString
        let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: nsString.length))

        guard matches.count == 2 else { return nil }

        func extract(match: NSTextCheckingResult) -> Double? {
            guard match.numberOfRanges == 5 else { return nil }
            let degStr = nsString.substring(with: match.range(at: 1))
            let minStr = nsString.substring(with: match.range(at: 2))
            let secStr = nsString.substring(with: match.range(at: 3))
            let dirStr = nsString.substring(with: match.range(at: 4)).uppercased()

            guard let deg = Double(degStr), let min = Double(minStr), let sec = Double(secStr) else { return nil }
            var decimal = deg + (min / 60.0) + (sec / 3600.0)
            if dirStr == "S" || dirStr == "W" {
                decimal = -decimal
            }
            return decimal
        }

        guard let lat = extract(match: matches[0]),
              let lon = extract(match: matches[1]) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Formatage des Grandeurs Métriques / Impériales

    /// Formate la distance en mètres ou kilomètres (ou pieds / miles en impérial).
    public static func formatDistance(_ meters: Double, isMetric: Bool = true) -> String {
        let safeMeters = max(0.0, meters)
        if isMetric {
            if safeMeters < 1_000.0 {
                return String(format: "%.0f m", safeMeters)
            } else {
                return String(format: "%.2f km", safeMeters / 1_000.0)
            }
        } else {
            let feet = safeMeters * 3.28084
            if feet < 5_280.0 {
                return String(format: "%.0f ft", feet)
            } else {
                return String(format: "%.2f mi", feet / 5_280.0)
            }
        }
    }

    /// Formate la vitesse (m/s vers km/h en métrique, ou mph en impérial).
    public static func formatSpeed(_ metersPerSecond: Double, isMetric: Bool = true) -> String {
        let safeSpeed = max(0.0, metersPerSecond)
        if isMetric {
            let kmh = safeSpeed * 3.6
            return String(format: "%0.1f km/h", kmh)
        } else {
            let mph = safeSpeed * 2.23694
            return String(format: "%0.1f mph", mph)
        }
    }

    /// Formate l'altitude en mètres ou pieds.
    public static func formatAltitude(_ meters: Double, isMetric: Bool = true) -> String {
        if isMetric {
            return String(format: "%.0f m", meters)
        } else {
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        }
    }

    /// Formate l'incertitude horizontale de la mesure GPS.
    public static func formatAccuracy(_ meters: Double, isMetric: Bool = true) -> String {
        if meters < 0.0 {
            return "N/A"
        }
        if isMetric {
            return String(format: "± %.1f m", meters)
        } else {
            let feet = meters * 3.28084
            return String(format: "± %.1f ft", feet)
        }
    }

    /// Formate le cap (bearing) avec sa rose des vents (ex: `245° SO`).
    public static func formatCourse(_ degrees: Double) -> String {
        guard degrees >= 0.0 else { return "—°" }
        let normalized = degrees.truncatingRemainder(dividingBy: 360.0)
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
        let index = Int(round(normalized / 22.5)) % 16
        return String(format: "%03.0f° %@", normalized, directions[index])
    }

    /// Formate une durée en secondes en format lisible (ex: `1h 14m` ou `42s`).
    public static func formatDuration(_ seconds: Double) -> String {
        let totalSecs = Int(max(0.0, seconds))
        let hours = totalSecs / 3600
        let minutes = (totalSecs % 3600) / 60
        let secs = totalSecs % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
