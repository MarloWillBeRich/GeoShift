import SwiftUI

/// Vue principale englobant la barre d'onglets et l'affichage des notifications toasts éphémères.
public struct MainTabView: View {
    @Environment(AppState.self) private var appState

    public init() {
        // Personnalisation de l'apparence UIKit du TabBar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(GeoTheme.backgroundSecondary)

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(GeoTheme.textSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(GeoTheme.textSecondary)
        ]

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(GeoTheme.accentPrimary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(GeoTheme.accentPrimary)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .top) {
            TabView(selection: $state.selectedTab) {
                DashboardView()
                    .tabItem {
                        Label(TabIdentifier.dashboard.title, systemImage: TabIdentifier.dashboard.sfSymbol)
                    }
                    .tag(TabIdentifier.dashboard)

                RoutePlannerView()
                    .tabItem {
                        Label(TabIdentifier.routes.title, systemImage: TabIdentifier.routes.sfSymbol)
                    }
                    .tag(TabIdentifier.routes)

                FavoritesListView()
                    .tabItem {
                        Label(TabIdentifier.favorites.title, systemImage: TabIdentifier.favorites.sfSymbol)
                    }
                    .tag(TabIdentifier.favorites)

                HistoryListView()
                    .tabItem {
                        Label(TabIdentifier.history.title, systemImage: TabIdentifier.history.sfSymbol)
                    }
                    .tag(TabIdentifier.history)

                SettingsView()
                    .tabItem {
                        Label(TabIdentifier.settings.title, systemImage: TabIdentifier.settings.sfSymbol)
                    }
                    .tag(TabIdentifier.settings)
            }
            .tint(GeoTheme.accentPrimary)

            // Bannière Toast éphémère flottante en haut de l'écran
            if let toast = appState.toastMessage {
                ToastBanner(message: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(GeoTheme.springAnimation, value: appState.toastMessage)
    }
}

private struct ToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(GeoTheme.accentPrimary)
                .font(.system(size: 15, weight: .semibold))

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GeoTheme.textPrimary)
                .lineLimit(2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .glassPanel(cornerRadius: 30)
        .padding(.top, 12)
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}
