import Foundation
import MapKit

/// Résultat détaillé d'un calcul d'itinéraire multi-étapes.
public struct CalculatedRoute: Sendable, Equatable {
    public let coordinates: [CLLocationCoordinate2D]
    public let totalDistanceMeters: Double
    public let expectedDurationSeconds: Double
    public let transportType: MKDirectionsTransportType
    public let stepInstructions: [String]

    public init(
        coordinates: [CLLocationCoordinate2D],
        totalDistanceMeters: Double,
        expectedDurationSeconds: Double,
        transportType: MKDirectionsTransportType,
        stepInstructions: [String] = []
    ) {
        self.coordinates = coordinates
        self.totalDistanceMeters = totalDistanceMeters
        self.expectedDurationSeconds = expectedDurationSeconds
        self.transportType = transportType
        self.stepInstructions = stepInstructions
    }

    public static func == (lhs: CalculatedRoute, rhs: CalculatedRoute) -> Bool {
        lhs.coordinates.count == rhs.coordinates.count &&
        abs(lhs.totalDistanceMeters - rhs.totalDistanceMeters) < 1.0 &&
        abs(lhs.expectedDurationSeconds - rhs.expectedDurationSeconds) < 1.0 &&
        lhs.transportType == rhs.transportType
    }
}

/// Service de calcul d'itinéraires et d'extraction de géométries de tracé via MKDirections.
public enum RouteCalculatorService {

    /// Calcule un itinéraire routier ou pédestre complet entre deux ou plusieurs coordonnées géographiques.
    public static func calculateRoute(
        between waypoints: [CLLocationCoordinate2D],
        transportType: MKDirectionsTransportType = .automobile
    ) async throws -> CalculatedRoute {
        guard waypoints.count >= 2 else {
            throw NSError(
                domain: "GeoShift.RouteCalculator",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Au moins 2 points sont requis pour calculer un itinéraire."]
            )
        }

        var aggregatedCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance: Double = 0.0
        var totalDuration: Double = 0.0
        var aggregatedSteps: [String] = []

        // Calcul par segments consécutifs pour supporter le multi-étapes sans limitation
        for i in 0..<(waypoints.count - 1) {
            let startCoord = waypoints[i]
            let endCoord = waypoints[i + 1]

            do {
                let segmentRoute = try await calculateSingleSegment(
                    from: startCoord,
                    to: endCoord,
                    transportType: transportType
                )

                let segmentCoords = extractCoordinates(from: segmentRoute.polyline)

                // Évite la duplication du point de jonction
                if !aggregatedCoordinates.isEmpty && !segmentCoords.isEmpty {
                    aggregatedCoordinates.append(contentsOf: segmentCoords.dropFirst())
                } else {
                    aggregatedCoordinates.append(contentsOf: segmentCoords)
                }

                totalDistance += segmentRoute.distance
                totalDuration += segmentRoute.expectedTravelTime

                for step in segmentRoute.steps where !step.instructions.isEmpty {
                    aggregatedSteps.append(step.instructions)
                }
            } catch {
                // En cas d'erreur réseau ou absence de route carrossable, fallback en ligne géodésique directe
                let directDistance = GeoMath.haversineDistance(from: startCoord, to: endCoord)
                totalDistance += directDistance
                let estimatedSpeed = transportType == .walking ? (5.0 / 3.6) : (50.0 / 3.6)
                totalDuration += directDistance / estimatedSpeed

                if aggregatedCoordinates.isEmpty {
                    aggregatedCoordinates.append(startCoord)
                }
                aggregatedCoordinates.append(endCoord)
                aggregatedSteps.append("Segment direct")
            }
        }

        return CalculatedRoute(
            coordinates: aggregatedCoordinates,
            totalDistanceMeters: totalDistance,
            expectedDurationSeconds: totalDuration,
            transportType: transportType,
            stepInstructions: aggregatedSteps
        )
    }

    private static func calculateSingleSegment(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = transportType
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let primaryRoute = response.routes.first else {
            throw NSError(
                domain: "GeoShift.RouteCalculator",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Aucun itinéraire trouvé pour ce segment."]
            )
        }

        return primaryRoute
    }

    /// Extrait la liste des coordonnées géographiques ordonnées depuis une MKPolyline.
    public static func extractCoordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let count = polyline.pointCount
        guard count > 0 else { return [] }

        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: count)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords
    }
}
