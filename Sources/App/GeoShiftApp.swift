import SwiftUI
import SwiftData

/// Point d'entrée principal de l'application GeoShift (iOS 17+ / Swift 6).
@main
struct GeoShiftApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            FavoriteLocation.self,
            SavedRoute.self,
            HistoryEntry.self
        ])
    }
}
