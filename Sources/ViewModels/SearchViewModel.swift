import Foundation
import SwiftUI
import MapKit
import Observation
import CoreLocation

/// ViewModel assurant la saisie avec autocomplétion, le filtrage et la détection de coordonnées directes.
@Observable
@MainActor
public final class SearchViewModel {
    public var searchQuery: String = "" {
        didSet {
            handleQueryChange()
        }
    }

    public let searchService: MapSearchService
    public var directCoordinateMatch: CLLocationCoordinate2D?
    public var isResolving: Bool = false
    public var errorMessage: String?

    private var debounceTask: Task<Void, Never>?

    public init(searchService: MapSearchService = MapSearchService()) {
        self.searchService = searchService
    }

    public var suggestions: [SearchResultSuggestion] {
        searchService.suggestions
    }

    public var isSearching: Bool {
        searchService.isSearching || isResolving
    }

    private func handleQueryChange() {
        debounceTask?.cancel()
        errorMessage = nil

        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Analyse si l'utilisateur a collé des coordonnées brutes (ex: 48.858844, 2.294350)
        if let parsed = CoordinateFormatter.parseCoordinate(from: trimmed) {
            self.directCoordinateMatch = parsed
        } else {
            self.directCoordinateMatch = nil
        }

        guard !trimmed.isEmpty else {
            searchService.updateQuery("")
            return
        }

        // 2. Étranglement (Debounce 300ms) pour les requêtes MapKit
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            self.searchService.updateQuery(trimmed)
        }
    }

    /// Résout la coordonnée finale pour une suggestion sélectionnée.
    public func selectSuggestion(_ suggestion: SearchResultSuggestion) async -> CLLocationCoordinate2D? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        do {
            let coord = try await searchService.resolveCoordinate(for: suggestion)
            return coord
        } catch {
            self.errorMessage = "Impossible de localiser cette adresse : \(error.localizedDescription)"
            return nil
        }
    }
}
