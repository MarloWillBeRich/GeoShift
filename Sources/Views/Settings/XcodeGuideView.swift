import SwiftUI

/// Guide interactif expliquant l'installation par Sideloading (sans compte payant)
/// et l'intégration du pont de simulation GPX officiel avec Apple Xcode.
public struct XcodeGuideView: View {
    @State private var demoGPXURL: URL?
    @State private var isSharePresented: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section Sideloading & Compte Gratuit
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(GeoTheme.accentPrimary)

                        Text("Sideloading (Compte Apple Gratuit)")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(GeoTheme.textPrimary)
                    }

                    Text("GeoShift est compilé **sans aucun entitlement payant restreint** (aucun Push, ni CloudKit obligatoire). L'archive **`GeoShift-Sideload.ipa`** est 100% installable gratuitement avec votre simple identifiant Apple personnel via **Sideloadly** (Windows/Mac), **AltStore**, **SideStore**, **Feather** ou **TrollStore** (sans expiration sur iOS compatibles).")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(GeoTheme.textSecondary)
                        .lineSpacing(3)
                }
                .padding(16)
                .cardSurface()

                // Guide Pas à Pas Sideloadly (Windows & Mac)
                Text("INSTALLATION VIA SIDELOADLY / ALTSTORE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GeoTheme.textSecondary)
                    .padding(.horizontal, 4)

                stepCard(
                    number: 1,
                    title: "Télécharger GeoShift-Sideload.ipa",
                    description: "Récupérez le fichier .ipa généré via le workflow GitHub Actions (artefact 'GeoShift-Sideload-IPA') ou compilé via le script build_sideload_ipa.sh.",
                    icon: "arrow.down.doc.fill"
                )

                stepCard(
                    number: 2,
                    title: "Brancher l'iPhone et ouvrir Sideloadly",
                    description: "Branchez votre iPhone à votre PC (Windows) ou Mac, glissez le fichier .ipa dans Sideloadly et renseignez votre Apple ID gratuit pour signer l'application.",
                    icon: "cable.connector"
                )

                stepCard(
                    number: 3,
                    title: "Valider le profil développeur sur iOS",
                    description: "Sur votre iPhone, rendez-vous dans Réglages > Confidentialité et sécurité > Mode développeur (Activer), puis Réglages > Général > Gestion des appareils pour approuver votre certificat.",
                    icon: "checkmark.shield.fill"
                )

                // Accès direct aux fichiers GPX
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(GeoTheme.accentSecondary)

                        Text("Dossier Partagé 'Fichiers' iOS")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(GeoTheme.textPrimary)
                    }

                    Text("Grâce à `UIFileSharingEnabled`, chaque fichier .gpx généré ou exporté dans GeoShift est directement stocké et accessible dans l'application officielle **Fichiers iOS** :")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(GeoTheme.textSecondary)

                    HStack(spacing: 6) {
                        Image(systemName: "iphone")
                            .foregroundStyle(GeoTheme.accentPrimary)
                        Text("Fichiers > Sur mon iPhone > GeoShift")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(GeoTheme.textPrimary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(GeoTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Vous pouvez ainsi brancher votre iPhone en USB sur un PC Windows ou Mac et récupérer instantanément tous vos fichiers GPX sans passer par le Cloud.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(GeoTheme.textSecondary)
                }
                .padding(16)
                .cardSurface()

                // Guide Pas à Pas Simulation Système Xcode
                Text("PILOTAGE DU GPS SYSTÈME (XCODE & OUTILS PC)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GeoTheme.textSecondary)
                    .padding(.horizontal, 4)

                stepCard(
                    number: 4,
                    title: "Injecter le GPX dans Xcode",
                    description: "Sur Mac, glissez le .gpx dans Xcode. Dans Edit Scheme > Run > Options, cochez 'Simulate Location' et sélectionnez votre tracé. Xcode rejouera fidèlement la vitesse interpolée par GeoShift !",
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
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(GeoTheme.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Sideloading & Guide Xcode")
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
                        .font(.system(size: 14, weight: .bold, design: .rounded))
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
