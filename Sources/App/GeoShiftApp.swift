import SwiftUI
import SwiftData

/// Point d'entrée principal de l'application GeoShift (iOS 17+ / Swift 6).
@main
struct GeoShiftApp: App {
    @State private var appState = AppState()
    private let container: ModelContainer

    public init() {
        let schema = Schema([
            FavoriteLocation.self,
            SavedRoute.self,
            HistoryEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ [SwiftData] Erreur d'initialisation du stockage persistant : \(error). Basculement vers stockage en mémoire de secours.")
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                self.container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("Impossible d'initialiser le stockage SwiftData de secours : \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
