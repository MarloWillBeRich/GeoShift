import SwiftUI
import SwiftData

/// Vue des réglages de l'application (Unités, Haptique, Carte, SwiftData et documentation Xcode).
public struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var allFavorites: [FavoriteLocation]
    @Query private var allRoutes: [SavedRoute]
    @Query private var allHistory: [HistoryEntry]

    @State private var isPurgeConfirmationPresented: Bool = false

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        NavigationStack {
            ZStack {
                GeoTheme.backgroundPrimary.ignoresSafeArea()

                Form {
                    // Préférences Générales
                    Section("PRÉFÉRENCES D'AFFICHAGE") {
                        Toggle(isOn: $state.isMetric) {
                            Label("Système Métrique (km/h, m)", systemImage: "ruler")
                        }

                        Toggle(isOn: $state.hapticsEnabled) {
                            Label("Retour Haptique", systemImage: "iphone.radiowaves.left.and.right")
                        }

                        Toggle(isOn: $state.autoCenterMap) {
                            Label("Centrage Auto Caméra", systemImage: "viewfinder")
                        }

                        Picker("Style de Carte", selection: $state.mapStyle) {
                            ForEach(AppMapStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                    }
                    .listRowBackground(GeoTheme.cardSurface)

                    // Intégration Développeur & Xcode
                    Section("INTÉGRATION OUTILS APPLE") {
                        NavigationLink {
                            XcodeGuideView()
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pont Développeur Xcode")
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(GeoTheme.textPrimary)
                                    Text("Guide d'injection de GPX pour simulation système")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(GeoTheme.textSecondary)
                                }
                            } icon: {
                                Image(systemName: "hammer.fill")
                                    .foregroundStyle(GeoTheme.accentPrimary)
                            }
                        }
                    }
                    .listRowBackground(GeoTheme.cardSurface)

                    // Métriques & Persistance SwiftData
                    Section("DONNÉES LOCALES (SWIFTDATA)") {
                        HStack {
                            Text("Lieux favoris")
                            Spacer()
                            Text("\(allFavorites.count)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(GeoTheme.textSecondary)
                        }

                        HStack {
                            Text("Itinéraires sauvegardés")
                            Spacer()
                            Text("\(allRoutes.count)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(GeoTheme.textSecondary)
                        }

                        HStack {
                            Text("Entrées d'historique")
                            Spacer()
                            Text("\(allHistory.count)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(GeoTheme.textSecondary)
                        }

                        Button(role: .destructive) {
                            isPurgeConfirmationPresented = true
                        } label: {
                            Label("Purger toutes les données", systemImage: "trash.fill")
                                .foregroundStyle(GeoTheme.statusError)
                        }
                    }
                    .listRowBackground(GeoTheme.cardSurface)

                    // Spécifications d'Architecture
                    Section("ARCHITECTURE SYSTÈME") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0 (Build 1)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(GeoTheme.textSecondary)
                        }

                        HStack {
                            Text("Langage")
                            Spacer()
                            Text("Swift 6.0 (Strict Concurrency)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(GeoTheme.textSecondary)
                        }

                        HStack {
                            Text("Cible")
                            Spacer()
                            Text("iOS 17.0+ (iPhone 15, 16, 17+)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(GeoTheme.textSecondary)
                        }

                        HStack {
                            Text("Sandbox Conformance")
                            Spacer()
                            Text("Apple App Store Compliant")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(GeoTheme.statusSuccess)
                        }
                    }
                    .listRowBackground(GeoTheme.cardSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Réglages")
            .confirmationDialog(
                "Purger toutes les données stockées ?",
                isPresented: $isPurgeConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Tout effacer définitivement", role: .destructive) {
                    purgeAllData()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action supprimera tous vos favoris, itinéraires et entrées d'historique.")
            }
        }
    }

    private func purgeAllData() {
        for fav in allFavorites { modelContext.delete(fav) }
        for route in allRoutes { modelContext.delete(route) }
        for entry in allHistory { modelContext.delete(entry) }
        appState.showToast("Données locales purgées")
    }
}
