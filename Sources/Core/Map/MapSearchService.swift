import Foundation
import MapKit
import Observation

/// Suggestion de recherche de lieu avec ses métadonnées d'affichage.
public struct SearchResultSuggestion: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let completion: MKLocalSearchCompletion?

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        completion: MKLocalSearchCompletion? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.completion = completion
    }

    public static func == (lhs: SearchResultSuggestion, rhs: SearchResultSuggestion) -> Bool {
        lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
    }
}

/// Service de recherche et d'autocomplétion basé sur MapKit (MKLocalSearchCompleter & MKLocalSearch).
@Observable
@MainActor
public final class MapSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer: MKLocalSearchCompleter
    public private(set) var suggestions: [SearchResultSuggestion] = []
    public private(set) var isSearching: Bool = false

    public override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Met à jour la requête d'autocomplétion en temps réel.
    public func updateQuery(_ query: String, region: MKCoordinateRegion? = nil) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            isSearching = false
            return
        }

        if let region {
            completer.region = region
        }
        isSearching = true
        completer.queryFragment = trimmed
    }

    /// Résout la coordonnée géographique exacte d'une suggestion d'autocomplétion.
    public func resolveCoordinate(for suggestion: SearchResultSuggestion) async throws -> CLLocationCoordinate2D {
        if let completion = suggestion.completion {
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            if let first = response.mapItems.first {
                return first.placemark.coordinate
            }
        }

        // Recherche par titre et sous-titre si pas de completion directe
        let fallbackRequest = MKLocalSearch.Request()
        fallbackRequest.naturalLanguageQuery = "\(suggestion.title) \(suggestion.subtitle)"
        let fallbackSearch = MKLocalSearch(request: fallbackRequest)
        let response = try await fallbackSearch.start()
        guard let first = response.mapItems.first else {
            throw NSError(domain: "GeoShift.Search", code: 404, userInfo: [NSLocalizedDescriptionKey: "Lieu introuvable"])
        }
        return first.placemark.coordinate
    }

    /// Recherche libre par mot-clé dans une région donnée.
    public func searchDirect(query: String, region: MKCoordinateRegion? = nil) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region {
            request.region = region
        }
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems
    }

    // MARK: - MKLocalSearchCompleterDelegate

    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.isSearching = false
        self.suggestions = completer.results.map { comp in
            SearchResultSuggestion(
                title: comp.title,
                subtitle: comp.subtitle,
                completion: comp
            )
        }
    }

    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.isSearching = false
        self.suggestions = []
    }
}
