import SwiftUI
import SwiftData

/// Journal d'activité complet consignant les démarrages de télémétrie, simulations et exports.
public struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \HistoryEntry.timestamp, order: .reverse)
    private var historyEntries: [HistoryEntry]

    @State private var isClearConfirmationPresented: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                GeoTheme.backgroundPrimary.ignoresSafeArea()

                if historyEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundStyle(GeoTheme.textSecondary)

                        Text("Aucun historique")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(GeoTheme.textPrimary)

                        Text("Vos actions de simulation et de recherche apparaîtront ici automatiquement.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(GeoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(historyEntries) { entry in
                            Button {
                                appState.startSimulation(
                                    coordinate: entry.coordinate,
                                    name: entry.title
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: entry.actionType.sfSymbol)
                                        .font(.system(size: 18))
                                        .foregroundStyle(GeoTheme.accentPrimary)
                                        .frame(width: 36, height: 36)
                                        .background(GeoTheme.accentPrimary.opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(entry.title)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(GeoTheme.textPrimary)

                                            Spacer()

                                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 10, design: .rounded))
                                                .foregroundStyle(GeoTheme.textSecondary)
                                        }

                                        if !entry.subtitle.isEmpty {
                                            Text(entry.subtitle)
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundStyle(GeoTheme.textSecondary)
                                        }

                                        Text(CoordinateFormatter.formatCompact(entry.coordinate))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(GeoTheme.textSecondary.opacity(0.7))
                                    }
                                }
                                .padding(12)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(GeoTheme.cardSurface)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(entry)
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
            .navigationTitle("Historique Télémétrique")
            .toolbar {
                if !historyEntries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            isClearConfirmationPresented = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(GeoTheme.statusError)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Effacer l'historique complet ?",
                isPresented: $isClearConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Tout effacer", role: .destructive) {
                    clearAllHistory()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action supprimera définitivement tout le journal d'activité.")
            }
        }
    }

    private func clearAllHistory() {
        for entry in historyEntries {
            modelContext.delete(entry)
        }
        appState.showToast("Historique vidé")
    }
}
