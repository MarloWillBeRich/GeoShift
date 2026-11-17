import SwiftUI

/// Guide interactif expliquant l'intégration du pont de simulation GPX officiel avec Apple Xcode.
public struct XcodeGuideView: View {
    @State private var demoGPXURL: URL?
    @State private var isSharePresented: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Bannière d'introduction d'intégrité Apple
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(GeoTheme.statusWarning)

                        Text("Conformité & Sandbox Apple")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(GeoTheme.textPrimary)
                    }

                    Text("Sur un appareil iOS officiel non-jailbreaké, la sécurité du bac à sable (Sandbox) interdit rigoureusement à une application tierce de modifier le GPS global du système pour les autres applications.\n\nGeoShift résout ce défi grâce à son générateur de fichiers **.gpx standardisés 1.1** avec horodatage séquentiel, permettant de piloter officiellement le moteur de simulation de localisation d'Apple via Xcode.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(GeoTheme.textSecondary)
                        .lineSpacing(3)
                }
                .padding(16)
                .cardSurface()

                // Guide Pas à Pas
                Text("PROTOCOLE DE CONNEXION XCODE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GeoTheme.textSecondary)
                    .padding(.horizontal, 4)

                stepCard(
                    number: 1,
                    title: "Créer et exporter l'itinéraire",
                    description: "Dans l'onglet 'Itinéraires', composez votre parcours, ajustez la vitesse voulue (ex: Voiture 50 km/h) puis touchez 'GPX' pour exporter le fichier via AirDrop vers votre Mac.",
                    icon: "square.and.arrow.up"
                )

                stepCard(
                    number: 2,
                    title: "Intégrer le .gpx dans Xcode",
                    description: "Glissez-déposez le fichier .gpx dans l'arborescence de votre projet iOS sur Xcode (Mac). Cochez 'Copy items if needed'.",
                    icon: "folder.badge.plus"
                )

                stepCard(
                    number: 3,
                    title: "Activer la simulation au lancement",
                    description: "Dans Xcode, cliquez sur votre Scheme > Edit Scheme... > Onglet 'Run' > Onglet 'Options' > Cochez 'Simulate Location' et sélectionnez votre fichier .gpx.",
                    icon: "gearshape.2"
                )

                stepCard(
                    number: 4,
                    title: "Contrôler en direct pendant le débogage",
                    description: "Lorsque l'application tourne sur votre iPhone en USB ou Wi-Fi, utilisez la barre de débogage Xcode : Debug > Simulate Location > Votre Fichier GPX. Xcode interpolera la vitesse exactement selon les balises générées par GeoShift !",
                    icon: "play.circle.fill"
                )

                // Bouton d'export de démonstration
                Button {
                    exportDemoGPX()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Exporter le fichier GPX de Démo (Paris)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GeoPrimaryButtonStyle())
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(GeoTheme.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Pont Développeur Xcode")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSharePresented) {
            if let url = demoGPXURL {
                ShareSheetView(activityItems: [url])
            }
        }
    }

    private func stepCard(number: Int, title: String, description: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(GeoTheme.accentPrimary)
                .frame(width: 28, height: 28)
                .overlay(
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GeoTheme.textPrimary)

                    Spacer()

                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(GeoTheme.accentSecondary)
                }

                Text(description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(GeoTheme.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .cardSurface()
    }

    private func exportDemoGPX() {
        let content = GPXExporter.generateRouteGPX(
            name: "Traversée de Paris",
            coordinates: [
                CLLocationCoordinate2D(latitude: 48.858844, longitude: 2.294350), // Tour Eiffel
                CLLocationCoordinate2D(latitude: 48.865633, longitude: 2.321236), // Concorde
                CLLocationCoordinate2D(latitude: 48.860611, longitude: 2.337644)  // Louvre
            ],
            speedMetersPerSecond: 13.89 // 50 km/h
        )

        if let url = GPXExporter.createTemporaryGPXFile(content: content, filename: "DemoRoute_Paris") {
            demoGPXURL = url
            isSharePresented = true
        }
    }
}
