import SwiftUI
import CoreLocation
import SwiftData

/// Feuille modale permettant la saisie manuelle de coordonnées et le déclenchement immédiat de simulation.
public struct QuickSimulationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var latitudeText: String
    @State private var longitudeText: String
    @State private var altitudeText: String
    @State private var accuracyText: String
    @State private var locationName: String = ""
    @State private var errorMessage: String?

    public init(
        initialCoordinate: CLLocationCoordinate2D? = nil,
        initialAltitude: Double = 35.0,
        initialAccuracy: Double = 5.0
    ) {
        if let initialCoordinate {
            _latitudeText = State(initialValue: String(format: "%.6f", initialCoordinate.latitude))
            _longitudeText = State(initialValue: String(format: "%.6f", initialCoordinate.longitude))
        } else {
            _latitudeText = State(initialValue: "48.858844")
            _longitudeText = State(initialValue: "2.294350")
        }
        _altitudeText = State(initialValue: String(format: "%.1f", initialAltitude))
        _accuracyText = State(initialValue: String(format: "%.1f", initialAccuracy))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                GeoTheme.backgroundSecondary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Section Saisie
                        VStack(alignment: .leading, spacing: 14) {
                            Text("COORDONNÉES CIBLES")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(GeoTheme.textSecondary)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Latitude (-90 à +90)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(GeoTheme.textSecondary)
                                    TextField("ex: 48.858844", text: $latitudeText)
                                        .keyboardType(.numbersAndPunctuation)
                                        .textFieldStyle(GeoTextFieldStyle())
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Longitude (-180 à +180)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(GeoTheme.textSecondary)
                                    TextField("ex: 2.294350", text: $longitudeText)
                                        .keyboardType(.numbersAndPunctuation)
                                        .textFieldStyle(GeoTextFieldStyle())
                                }
                            }

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Altitude (m)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(GeoTheme.textSecondary)
                                    TextField("35.0", text: $altitudeText)
                                        .keyboardType(.numbersAndPunctuation)
                                        .textFieldStyle(GeoTextFieldStyle())
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Précision (m)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(GeoTheme.textSecondary)
                                    TextField("5.0", text: $accuracyText)
                                        .keyboardType(.numbersAndPunctuation)
                                        .textFieldStyle(GeoTextFieldStyle())
                                }
                            }

                            Button {
                                pasteFromClipboard()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Coller depuis le presse-papier")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(GeoTheme.accentPrimary)
                            }
                            .padding(.top, 2)
                        }
                        .padding(16)
                        .cardSurface()

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(GeoTheme.statusError)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        // Préréglages Mondiaux Rapides
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PRÉRÉGLAGES RAPIDES")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(GeoTheme.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    presetButton(name: "Tour Eiffel", lat: 48.858844, lon: 2.294350)
                                    presetButton(name: "Times Square", lat: 40.7580, lon: -73.9855)
                                    presetButton(name: "Shibuya Crossing", lat: 35.6595, lon: 139.7005)
                                    presetButton(name: "Golden Gate", lat: 37.8199, lon: -122.4783)
                                    presetButton(name: "Opéra de Sydney", lat: -33.8568, lon: 151.2153)
                                }
                            }
                        }
                        .padding(16)
                        .cardSurface()

                        // Boutons d'Action
                        VStack(spacing: 12) {
                            Button {
                                applySimulation()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                    Text("Activer la Simulation Fixe")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GeoPrimaryButtonStyle())

                            Button {
                                saveAsFavorite()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "star.fill")
                                    Text("Enregistrer dans les Favoris")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GeoSecondaryButtonStyle())

                            if appState.locationEngine.isSimulating {
                                Button {
                                    appState.restoreRealGPS()
                                    dismiss()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Rétablir le GPS Matériel")
                                    }
                                    .foregroundStyle(GeoTheme.statusWarning)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(GeoSecondaryButtonStyle())
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Simulation Manuelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundStyle(GeoTheme.textSecondary)
                }
            }
        }
    }

    private func presetButton(name: String, lat: Double, lon: Double) -> some View {
        Button {
            latitudeText = String(format: "%.6f", lat)
            longitudeText = String(format: "%.6f", lon)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GeoTheme.textPrimary)
                Text(String(format: "%.3f, %.3f", lat, lon))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(GeoTheme.textSecondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(GeoTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private func pasteFromClipboard() {
        guard let string = UIPasteboard.general.string,
              let parsed = CoordinateFormatter.parseCoordinate(from: string) else {
            errorMessage = "Aucune coordonnée valide trouvée dans le presse-papier."
            return
        }
        latitudeText = String(format: "%.6f", parsed.latitude)
        longitudeText = String(format: "%.6f", parsed.longitude)
        errorMessage = nil
    }

    private func parseInputs() -> (CLLocationCoordinate2D, Double, Double)? {
        guard let lat = Double(latitudeText.replacingOccurrences(of: ",", with: ".")),
              let lon = Double(longitudeText.replacingOccurrences(of: ",", with: ".")),
              GeoMath.isValidCoordinate(latitude: lat, longitude: lon) else {
            errorMessage = "Veuillez saisir des coordonnées valides (-90..90 et -180..180)."
            return nil
        }

        let alt = Double(altitudeText.replacingOccurrences(of: ",", with: ".")) ?? 35.0
        let acc = Double(accuracyText.replacingOccurrences(of: ",", with: ".")) ?? 5.0
        return (CLLocationCoordinate2D(latitude: lat, longitude: lon), alt, acc)
    }

    private func applySimulation() {
        guard let (coord, alt, acc) = parseInputs() else { return }

        appState.startSimulation(coordinate: coord, altitude: alt, accuracy: acc)

        // Sauvegarde dans l'historique
        let entry = HistoryEntry(
            actionType: .manualSimulation,
            title: "Simulation Manuelle",
            subtitle: CoordinateFormatter.formatCompact(coord),
            latitude: coord.latitude,
            longitude: coord.longitude
        )
        modelContext.insert(entry)

        dismiss()
    }

    private func saveAsFavorite() {
        guard let (coord, alt, _) = parseInputs() else { return }

        let name = locationName.isEmpty ? "Lieu \(CoordinateFormatter.formatCompact(coord))" : locationName
        let fav = FavoriteLocation(
            name: name,
            latitude: coord.latitude,
            longitude: coord.longitude,
            altitude: alt,
            category: "Général"
        )
        modelContext.insert(fav)

        let entry = HistoryEntry(
            actionType: .favoriteAdded,
            title: name,
            subtitle: "Ajouté aux favoris",
            latitude: coord.latitude,
            longitude: coord.longitude
        )
        modelContext.insert(entry)

        appState.showToast("Favori enregistré avec succès")
        dismiss()
    }
}

public struct GeoTextFieldStyle: TextFieldStyle {
    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(GeoTheme.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(GeoTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
