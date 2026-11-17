import SwiftUI
import CoreLocation
import MapKit

/// Vue modale de recherche d'adresse avec autocomplétion instantanée et détection de coordonnées directes.
public struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = SearchViewModel()

    public let onSelectCoordinate: (CLLocationCoordinate2D, String) -> Void

    public init(onSelectCoordinate: @escaping (CLLocationCoordinate2D, String) -> Void) {
        self.onSelectCoordinate = onSelectCoordinate
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                GeoTheme.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Barre de saisie
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(GeoTheme.accentPrimary)
                            .font(.system(size: 16, weight: .semibold))

                        TextField("Ville, adresse, lieu ou coordonnées...", text: $viewModel.searchQuery)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(GeoTheme.textPrimary)
                            .autocorrectionDisabled()

                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(GeoTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(GeoTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Détection directe de coordonnées
                    if let directCoord = viewModel.directCoordinateMatch {
                        Button {
                            onSelectCoordinate(directCoord, "Coordonnées directes")
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "scope")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(GeoTheme.accentPrimary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Coordonnées Directes Détectées")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(GeoTheme.textPrimary)

                                    Text(CoordinateFormatter.formatCompact(directCoord))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(GeoTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right.circle.fill")
                                    .foregroundStyle(GeoTheme.accentPrimary)
                            }
                            .padding(14)
                            .background(GeoTheme.accentPrimary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(GeoTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }

                    // Suggestions rapides (Chips)
                    if viewModel.searchQuery.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUGGESTIONS RAPIDES")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(GeoTheme.textSecondary)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    quickChip("Paris, France")
                                    quickChip("Tokyo, Japon")
                                    quickChip("New York, USA")
                                    quickChip("San Francisco, USA")
                                    quickChip("Londres, UK")
                                    quickChip("Berlin, Allemagne")
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Liste des résultats d'autocomplétion
                    if viewModel.isSearching {
                        ProgressView()
                            .tint(GeoTheme.accentPrimary)
                            .padding(.top, 30)
                        Spacer()
                    } else if !viewModel.suggestions.isEmpty {
                        List {
                            ForEach(viewModel.suggestions) { suggestion in
                                Button {
                                    Task {
                                        if let coord = await viewModel.selectSuggestion(suggestion) {
                                            onSelectCoordinate(coord, suggestion.title)
                                            dismiss()
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(GeoTheme.accentPrimary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.title)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(GeoTheme.textPrimary)

                                            if !suggestion.subtitle.isEmpty {
                                                Text(suggestion.subtitle)
                                                    .font(.system(size: 12, design: .rounded))
                                                    .foregroundStyle(GeoTheme.textSecondary)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(GeoTheme.cardSurface)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    } else if !viewModel.searchQuery.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 36))
                                .foregroundStyle(GeoTheme.textSecondary)
                            Text("Aucun résultat trouvé pour cette recherche")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(GeoTheme.textSecondary)
                        }
                        .padding(.top, 40)
                        Spacer()
                    } else {
                        Spacer()
                    }
                }
            }
            .navigationTitle("Recherche de Lieu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundStyle(GeoTheme.textSecondary)
                }
            }
        }
    }

    private func quickChip(_ title: String) -> some View {
        Button {
            viewModel.searchQuery = title
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(GeoTheme.textPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(GeoTheme.cardSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}
