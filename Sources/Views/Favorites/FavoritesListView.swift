import SwiftUI
import SwiftData
import CoreLocation

/// Vue de gestion des lieux favoris (CRUD SwiftData, filtrage par catégorie, recherche et simulation rapide).
public struct FavoritesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \FavoriteLocation.createdAt, order: .reverse)
    private var allFavorites: [FavoriteLocation]

    @State private var selectedCategory: String = "Tous"
    @State private var searchQuery: String = ""
    @State private var isAddSheetPresented: Bool = false

    public init() {}

    private var filteredFavorites: [FavoriteLocation] {
        allFavorites.filter { item in
            let matchesCategory = selectedCategory == "Tous" || item.category == selectedCategory
            let matchesQuery = searchQuery.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchQuery) ||
                item.notes.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesQuery
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                GeoTheme.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Sélecteur de Catégories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryPill("Tous")
                            ForEach(FavoriteLocation.defaultCategories, id: \.self) { cat in
                                categoryPill(cat)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    if filteredFavorites.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(GeoTheme.textSecondary)

                            Text("Aucun lieu favori trouvé")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(GeoTheme.textPrimary)

                            Text("Enregistrez vos positions clés pour les simuler instantanément d'un simple toucher.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(GeoTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredFavorites) { favorite in
                                FavoriteCardRow(favorite: favorite) {
                                    appState.startSimulation(
                                        coordinate: favorite.coordinate,
                                        altitude: favorite.altitude,
                                        name: favorite.name
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        modelContext.delete(favorite)
                                    } label: {
                                        Label("Supprimer", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Lieux Favoris")
            .searchable(text: $searchQuery, prompt: "Filtrer vos favoris...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddSheetPresented = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(GeoTheme.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $isAddSheetPresented) {
                AddFavoriteSheet()
            }
        }
    }

    private func categoryPill(_ category: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(category)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedCategory == category ? Color.white : GeoTheme.textSecondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(selectedCategory == category ? GeoTheme.accentPrimary : GeoTheme.cardSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

// MARK: - Ligne de Carte Favori

private struct FavoriteCardRow: View {
    let favorite: FavoriteLocation
    let onSimulate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(favorite.category)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(GeoTheme.accentSecondary)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(GeoTheme.accentSecondary.opacity(0.15))
                        .clipShape(Capsule())

                    Text(favorite.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GeoTheme.textPrimary)
                }

                if !favorite.notes.isEmpty {
                    Text(favorite.notes)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(GeoTheme.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(CoordinateFormatter.formatCompact(favorite.coordinate))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(GeoTheme.textSecondary)

                    Text("•")
                        .foregroundStyle(GeoTheme.textSecondary.opacity(0.5))

                    Text(String(format: "%.0f m", favorite.altitude))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(GeoTheme.textSecondary)
                }
            }

            Spacer()

            Button {
                onSimulate()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Simuler")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(GeoTheme.accentPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .cardSurface()
    }
}

// MARK: - Feuille d'Ajout de Favori

private struct AddFavoriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var category: String = "Général"
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""
    @State private var altitudeText: String = "35.0"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GeoTheme.backgroundSecondary.ignoresSafeArea()

                Form {
                    Section("INFORMATIONS GÉNÉRALES") {
                        TextField("Nom du lieu", text: $name)
                        TextField("Notes ou repère", text: $notes)
                        Picker("Catégorie", selection: $category) {
                            ForEach(FavoriteLocation.defaultCategories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                    }
                    .listRowBackground(GeoTheme.cardSurface)

                    Section("COORDONNÉES") {
                        TextField("Latitude (-90 à +90)", text: $latitudeText)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Longitude (-180 à +180)", text: $longitudeText)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Altitude (m)", text: $altitudeText)
                            .keyboardType(.numbersAndPunctuation)

                        Button("Utiliser la position active actuelle") {
                            let current = appState.locationEngine.currentSnapshot
                            latitudeText = String(format: "%.6f", current.coordinate.latitude)
                            longitudeText = String(format: "%.6f", current.coordinate.longitude)
                            altitudeText = String(format: "%.1f", current.altitude)
                        }
                        .foregroundStyle(GeoTheme.accentPrimary)
                    }
                    .listRowBackground(GeoTheme.cardSurface)

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(GeoTheme.statusError)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Nouveau Favori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(GeoTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        save()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(GeoTheme.accentPrimary)
                }
            }
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Veuillez saisir un nom pour ce lieu."
            return
        }

        guard let lat = Double(latitudeText.replacingOccurrences(of: ",", with: ".")),
              let lon = Double(longitudeText.replacingOccurrences(of: ",", with: ".")),
              GeoMath.isValidCoordinate(latitude: lat, longitude: lon) else {
            errorMessage = "Coordonnées invalides."
            return
        }

        let alt = Double(altitudeText.replacingOccurrences(of: ",", with: ".")) ?? 35.0

        let fav = FavoriteLocation(
            name: name,
            notes: notes,
            latitude: lat,
            longitude: lon,
            altitude: alt,
            category: category
        )
        modelContext.insert(fav)
        dismiss()
    }
}
