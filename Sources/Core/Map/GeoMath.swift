import Foundation
import CoreLocation

/// Moteur de calcul géodésique pur Swift (WGS84, formules de Haversine, cap et interpolation).
public enum GeoMath {
    /// Rayon moyen de la Terre en mètres selon le modèle sphérique WGS84 standard.
    public static let earthRadiusMeters: Double = 6_371_000.0

    /// Résultat d'une étape d'interpolation le long d'une polyligne.
    public struct InterpolationResult: Sendable, Equatable {
        public let coordinate: CLLocationCoordinate2D
        public let course: Double
        public let segmentIndex: Int
        public let distanceFromStart: Double
        public let progress: Double
        public let isCompleted: Bool

        public init(
            coordinate: CLLocationCoordinate2D,
            course: Double,
            segmentIndex: Int,
            distanceFromStart: Double,
            progress: Double,
            isCompleted: Bool
        ) {
            self.coordinate = coordinate
            self.course = course
            self.segmentIndex = segmentIndex
            self.distanceFromStart = distanceFromStart
            self.progress = progress
            self.isCompleted = isCompleted
        }

        public static func == (lhs: InterpolationResult, rhs: InterpolationResult) -> Bool {
            abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < 1e-7 &&
            abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < 1e-7 &&
            abs(lhs.course - rhs.course) < 1e-4 &&
            lhs.segmentIndex == rhs.segmentIndex &&
            abs(lhs.distanceFromStart - rhs.distanceFromStart) < 1e-3 &&
            abs(lhs.progress - rhs.progress) < 1e-5 &&
            lhs.isCompleted == rhs.isCompleted
        }
    }

    // MARK: - Validation de coordonnées

    /// Valide la conformité stricte des coordonnées géographiques (-90..90 pour la latitude, -180..180 pour la longitude).
    public static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        guard !latitude.isNaN, !latitude.isInfinite, !longitude.isNaN, !longitude.isInfinite else {
            return false
        }
        return latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0 && longitude <= 180.0
    }

    /// Valide une structure `CLLocationCoordinate2D`.
    public static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        isValidCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// Clampe les coordonnées dans les bornes légales WGS84.
    public static func clampCoordinate(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        let clampedLat = min(max(latitude, -90.0), 90.0)
        var clampedLon = longitude
        if clampedLon < -180.0 || clampedLon > 180.0 {
            clampedLon = clampedLon.truncatingRemainder(dividingBy: 360.0)
            if clampedLon > 180.0 { clampedLon -= 360.0 }
            if clampedLon < -180.0 { clampedLon += 360.0 }
        }
        return CLLocationCoordinate2D(latitude: clampedLat, longitude: clampedLon)
    }

    // MARK: - Distance de Haversine

    /// Calcule la distance orthodromique exacte en mètres entre deux coordonnées géographiques.
    public static func haversineDistance(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> Double {
        let lat1Rad = start.latitude * .pi / 180.0
        let lat2Rad = end.latitude * .pi / 180.0
        let deltaLat = (end.latitude - start.latitude) * .pi / 180.0
        let deltaLon = (end.longitude - start.longitude) * .pi / 180.0

        let sinHalfDeltaLat = sin(deltaLat / 2.0)
        let sinHalfDeltaLon = sin(deltaLon / 2.0)

        let a = sinHalfDeltaLat * sinHalfDeltaLat +
                cos(lat1Rad) * cos(lat2Rad) * sinHalfDeltaLon * sinHalfDeltaLon
        let c = 2.0 * atan2(sqrt(a), sqrt(max(0.0, 1.0 - a)))

        return earthRadiusMeters * c
    }

    // MARK: - Calcul du Cap (Bearing)

    /// Calcule le cap initial (Initial Bearing) en degrés [0, 360) du point de départ vers le point d'arrivée.
    public static func initialBearing(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> Double {
        let lat1Rad = start.latitude * .pi / 180.0
        let lat2Rad = end.latitude * .pi / 180.0
        let deltaLonRad = (end.longitude - start.longitude) * .pi / 180.0

        let y = sin(deltaLonRad) * cos(lat2Rad)
        let x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLonRad)

        let radians = atan2(y, x)
        let degrees = radians * 180.0 / .pi
        return (degrees + 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    // MARK: - Point de Destination

    /// Calcule un nouveau point de coordonnées à partir d'un point d'origine, d'une distance en mètres et d'un cap en degrés.
    public static func destinationCoordinate(
        from start: CLLocationCoordinate2D,
        distanceMeters: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        guard distanceMeters > 0 else { return start }

        let angularDistance = distanceMeters / earthRadiusMeters
        let bearingRad = bearingDegrees * .pi / 180.0

        let lat1Rad = start.latitude * .pi / 180.0
        let lon1Rad = start.longitude * .pi / 180.0

        let sinLat1 = sin(lat1Rad)
        let cosLat1 = cos(lat1Rad)
        let sinAngDist = sin(angularDistance)
        let cosAngDist = cos(angularDistance)

        let lat2Rad = asin(sinLat1 * cosAngDist + cosLat1 * sinAngDist * cos(bearingRad))
        let lon2Rad = lon1Rad + atan2(
            sin(bearingRad) * sinAngDist * cosLat1,
            cosAngDist - sinLat1 * sin(lat2Rad)
        )

        let lat2Deg = lat2Rad * 180.0 / .pi
        var lon2Deg = lon2Rad * 180.0 / .pi

        // Normalisation de la longitude entre -180 et +180
        lon2Deg = (lon2Deg + 540.0).truncatingRemainder(dividingBy: 360.0) - 180.0

        return CLLocationCoordinate2D(latitude: lat2Deg, longitude: lon2Deg)
    }

    // MARK: - Calculs sur Polyligne

    /// Calcule la distance cumulée totale d'un ensemble ordonné de coordonnées en mètres.
    public static func totalDistance(of coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0.0 }
        var sum: Double = 0.0
        for i in 0..<(coordinates.count - 1) {
            sum += haversineDistance(from: coordinates[i], to: coordinates[i + 1])
        }
        return sum
    }

    /// Calcule le tableau des distances cumulées à chaque point (le premier point vaut 0).
    public static func cumulativeDistances(of coordinates: [CLLocationCoordinate2D]) -> [Double] {
        guard !coordinates.isEmpty else { return [] }
        var distances: [Double] = [0.0]
        distances.reserveCapacity(coordinates.count)
        var accumulated: Double = 0.0
        for i in 0..<(coordinates.count - 1) {
            accumulated += haversineDistance(from: coordinates[i], to: coordinates[i + 1])
            distances.append(accumulated)
        }
        return distances
    }

    // MARK: - Interpolation le long d'une polyligne

    /// Interpole la position et le cap instantané le long d'une polyligne à un ratio de progression donné [0.0, 1.0].
    public static func interpolate(
        along coordinates: [CLLocationCoordinate2D],
        progress: Double
    ) -> InterpolationResult? {
        guard !coordinates.isEmpty else { return nil }
        if coordinates.count == 1 {
            return InterpolationResult(
                coordinate: coordinates[0],
                course: 0.0,
                segmentIndex: 0,
                distanceFromStart: 0.0,
                progress: 1.0,
                isCompleted: true
            )
        }

        let clampedProgress = min(max(progress, 0.0), 1.0)
        let total = totalDistance(of: coordinates)
        if total <= 0.001 {
            return InterpolationResult(
                coordinate: coordinates[0],
                course: 0.0,
                segmentIndex: 0,
                distanceFromStart: 0.0,
                progress: 1.0,
                isCompleted: true
            )
        }

        let targetDistance = clampedProgress * total
        return interpolate(along: coordinates, distanceMeters: targetDistance, totalDistance: total)
    }

    /// Interpole la position le long d'une polyligne à une distance donnée en mètres depuis le départ.
    public static func interpolate(
        along coordinates: [CLLocationCoordinate2D],
        distanceMeters: Double,
        totalDistance precalculatedTotal: Double? = nil
    ) -> InterpolationResult? {
        guard !coordinates.isEmpty else { return nil }
        if coordinates.count == 1 {
            return InterpolationResult(
                coordinate: coordinates[0],
                course: 0.0,
                segmentIndex: 0,
                distanceFromStart: 0.0,
                progress: 1.0,
                isCompleted: true
            )
        }

        let total = precalculatedTotal ?? totalDistance(of: coordinates)
        if total <= 0.001 {
            return InterpolationResult(
                coordinate: coordinates[0],
                course: 0.0,
                segmentIndex: 0,
                distanceFromStart: 0.0,
                progress: 1.0,
                isCompleted: true
            )
        }

        if distanceMeters <= 0.0 {
            let initialCourse = initialBearing(from: coordinates[0], to: coordinates[1])
            return InterpolationResult(
                coordinate: coordinates[0],
                course: initialCourse,
                segmentIndex: 0,
                distanceFromStart: 0.0,
                progress: 0.0,
                isCompleted: false
            )
        }

        if distanceMeters >= total {
            let lastIdx = coordinates.count - 1
            let finalCourse = initialBearing(from: coordinates[lastIdx - 1], to: coordinates[lastIdx])
            return InterpolationResult(
                coordinate: coordinates[lastIdx],
                course: finalCourse,
                segmentIndex: lastIdx - 1,
                distanceFromStart: total,
                progress: 1.0,
                isCompleted: true
            )
        }

        // Parcours des segments pour trouver l'intervalle
        var accumulated: Double = 0.0
        for i in 0..<(coordinates.count - 1) {
            let segStart = coordinates[i]
            let segEnd = coordinates[i + 1]
            let segLength = haversineDistance(from: segStart, to: segEnd)

            if accumulated + segLength >= distanceMeters {
                let remainingDistance = distanceMeters - accumulated
                let bearing = initialBearing(from: segStart, to: segEnd)
                let interpolatedCoord = destinationCoordinate(
                    from: segStart,
                    distanceMeters: remainingDistance,
                    bearingDegrees: bearing
                )

                let currentProgress = total > 0 ? (distanceMeters / total) : 1.0
                return InterpolationResult(
                    coordinate: interpolatedCoord,
                    course: bearing,
                    segmentIndex: i,
                    distanceFromStart: distanceMeters,
                    progress: min(max(currentProgress, 0.0), 1.0),
                    isCompleted: false
                )
            }

            accumulated += segLength
        }

        // Cas limite résiduel
        let lastIdx = coordinates.count - 1
        let course = initialBearing(from: coordinates[lastIdx - 1], to: coordinates[lastIdx])
        return InterpolationResult(
            coordinate: coordinates[lastIdx],
            course: course,
            segmentIndex: lastIdx - 1,
            distanceFromStart: total,
            progress: 1.0,
            isCompleted: true
        )
    }

    // MARK: - Bruit GPS Réaliste (Jitter)

    /// Ajoute une micro-perturbation réaliste (bruit gaussien/circulaire) pour émuler la dérive d'un récepteur GPS matériel.
    public static func addGpsJitter(
        to coordinate: CLLocationCoordinate2D,
        maxRadiusMeters: Double
    ) -> CLLocationCoordinate2D {
        guard maxRadiusMeters > 0.0 else { return coordinate }
        let randomAngle = Double.random(in: 0.0..<360.0)
        // Distribution uniforme dans le disque : rayon = maxRadius * sqrt(u)
        let randomDistance = maxRadiusMeters * sqrt(Double.random(in: 0.0...1.0))
        return destinationCoordinate(
            from: coordinate,
            distanceMeters: randomDistance,
            bearingDegrees: randomAngle
        )
    }
}
