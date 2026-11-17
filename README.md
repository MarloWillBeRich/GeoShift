# GeoShift — iOS Native GPS Simulation & Route Engine (Sideloadable .IPA Edition)

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0%2B-blue?style=for-the-badge&logo=apple" alt="iOS 17.0+">
  <img src="https://img.shields.io/badge/Swift-6.0%20Strict%20Concurrency-orange?style=for-the-badge&logo=swift" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20MapKit-purple?style=for-the-badge" alt="SwiftUI + MapKit">
  <img src="https://img.shields.io/badge/Persistence-SwiftData-green?style=for-the-badge" alt="SwiftData">
  <img src="https://img.shields.io/badge/Sideloading-Zero%20Paid%20Entitlements-success?style=for-the-badge&logo=apple" alt="Sideloading Free Apple ID">
  <img src="https://img.shields.io/badge/XcodeGen-Ready-red?style=for-the-badge" alt="XcodeGen Ready">
</p>

---

## 1. Vue d'Ensemble & Vision Architecturale

**GeoShift** est une application iOS native industrielle conçue selon les plus hauts standards d'ingénierie logicielle Apple. Elle combine un moteur physique d'interpolation de télémétrie GPS en temps réel, un planificateur d'itinéraires multi-étapes propulsé par `MKDirections`, une persistance réactive `SwiftData` et un exportateur universel **GPX 1.1** optimisé pour le débogage officiel d'Apple (**Xcode Simulate Location**).

### Compatibilité Totale Sideloading (Compte Apple Gratuit)
Pour permettre à n'importe quel développeur ou utilisateur d'installer GeoShift sur un iPhone sans abonnement Apple Developer payant (99$/an) :
- **Zéro Entitlement Bloquant :** Aucune dépendance aux notifications push payantes, à CloudKit ou aux App Groups d'entreprise.
- **Stockage SwiftData Local :** Persistance 100% contenue dans la sandbox de l'application.
- **Dossier Partagé "Fichiers" iOS (`UIFileSharingEnabled`) :** Tous les tracés GPX créés sont immédiatement visibles dans l'application officielle *Fichiers > Sur mon iPhone > GeoShift*, et récupérables directement par câble USB sur Windows ou Mac.
- **Binaire Ad-Hoc / Sideload Ready :** Le script de build génère **`GeoShift-Sideload.ipa`** (et son clone `GeoShift-Unsigned.ipa`) prêt pour être signé et injecté par Sideloadly, AltStore, SideStore, Feather ou TrollStore.

---

## 2. Fonctionnalités Clés

- **Télémétrie en Direct (HUD)** : Surveillance à haute fréquence de la Latitude, Longitude, Altitude, Cap (Course avec rose des vents), Vitesse instantanée et Précision horizontale avec typographie monospacée (`.monospacedDigit()`) éliminant tout tressautement d'affichage.
- **Indicateur de Source Explicite** : Badge visuel dynamique distinguant `MATÉRIEL (GPS Réel)` de `SIMULATION LOCALE (Sandbox)`.
- **Interpolation Physique Réaliste** : Déplacement cinématique le long des polylignes routières calculées par `MKDirections` avec micro-bruit GPS réglable (jitter gaussien) et profils de vitesse prédéfinis (Marche 5 km/h, Course 12 km/h, Vélo 20 km/h, Ville 50 km/h, Autoroute 110 km/h, TGV 300 km/h).
- **Recherche & Détection Directe** : Autocomplétion temps réel via `MKLocalSearchCompleter` et analyse intelligente (parsing) des coordonnées décimales et DMS collées dans le champ de recherche.
- **Persistance SwiftData Réactive** : Sauvegarde et organisation des lieux favoris avec catégorisation, historique complet horodaté de toutes les actions et sauvegarde des trajets complexes.
- **Exportateur GPX Xcode** : Génération XML conforme au schéma TopoGrafix 1.1 avec horodatages séquentiels automatiques pour rejouer fidèlement la vitesse choisie dans le simulateur Apple.

---

## 3. Système de Design (Apple Dark Premium UI)

Le design system centralisé (`Core/DesignSystem/Theme.swift`) respecte une charte chromatique stricte et des composants visuels inspirés des interfaces professionnelles d'Apple :

| Rôle Visuel | Code Hexadécimal | Utilisation |
| :--- | :--- | :--- |
| **Fond Principal** | `#090B10` | Fond profond immersif |
| **Fond Secondaire** | `#121722` | Feuilles modales et barres de navigation |
| **Surface de Carte** | `#171E2B` | Cartes télémétriques avec bordure `1px` en `#FFFFFF` à 8% |
| **Accent Primaire** | `#48A9FF` | Tracé actif, curseurs, boutons principaux |
| **Accent Secondaire**| `#7C6CFF` | Itinéraires secondaires, badges de mode |
| **Succès** | `#35D49A` | Signal GPS actif, statut opérationnel |
| **Avertissement** | `#FFB84D` | Mode simulation sandbox, pause |
| **Erreur** | `#FF5C5C` | Échec de calcul, coordonnées hors bornes |
| **Texte Primaire** | `#F5F7FA` | Valeurs numériques et en-têtes |
| **Texte Secondaire**| `#929BAC` | Unités, labels de champs, métadonnées |

---

## 4. Arborescence du Projet

```text
GeoShift/
├── project.yml                                       # Configuration XcodeGen (iOS 17, Swift 6, sans entitlements payants)
├── .github/workflows/build-sideload-ipa.yml          # Pipeline CI macOS générant GeoShift-Sideload.ipa en Artifact
├── scripts/build_sideload_ipa.sh                     # Script de build Release sans certificat + création de Payload/ et GeoShift-Sideload.ipa
├── README.md                                         # Documentation d'architecture, guide Sideloading et guide GPX
├── Resources/
│   ├── Info.plist                                    # Permissions GPS + UIFileSharingEnabled pour accès Fichiers iOS
│   └── DemoRoute_Paris.gpx                           # Fichier GPX de démonstration valide
├── Sources/
│   ├── App/
│   │   ├── GeoShiftApp.swift                         # Point d'entrée, injection SwiftData & AppState
│   │   └── AppState.swift                            # État global @Observable @MainActor
│   ├── Core/
│   │   ├── DesignSystem/
│   │   │   ├── Theme.swift                           # Couleurs hex, typographies, styles de cartes et boutons
│   │   │   └── TelemetryBadge.swift                  # Composants UI réutilisables (statut GPS, pilules de données)
│   │   ├── Location/
│   │   │   ├── LocationProviderProtocol.swift        # Protocole unifié + struct TelemetrySnapshot Sendable
│   │   │   ├── RealLocationProvider.swift            # Wrapper CLLocationManager en AsyncStream<TelemetrySnapshot>
│   │   │   ├── SimulatedLocationProvider.swift       # Moteur de simulation statique et dynamique (interpolation)
│   │   │   └── LocationEngine.swift                  # Orchestrateur basculant entre Réel et Simulé + Reverse Geocoding
│   │   ├── Map/
│   │   │   ├── GeoMath.swift                         # Formules Haversine, Bearing (cap), Destination point, Interpolation
│   │   │   ├── MapSearchService.swift                # MKLocalSearchCompleter & MKLocalSearch async/await
│   │   │   └── RouteCalculatorService.swift          # Calcul d'itinéraires MKDirections + extraction des polylignes
│   │   └── Utilities/
│   │       ├── GPXExporter.swift                     # Génération XML GPX 1.1 valide (wpt, trk, trkseg, trkpt) et partage
│   │       └── CoordinateFormatter.swift             # Formatage DMS / Décimal et validation des bornes (-90..90, -180..180)
│   ├── Models/
│   │   ├── FavoriteLocation.swift                    # @Model SwiftData : id, name, notes, lat, lon, altitude, createdAt, category
│   │   ├── SavedRoute.swift                          # @Model SwiftData : id, name, waypointsData, distance, duration, createdAt
│   │   ├── HistoryEntry.swift                        # @Model SwiftData : id, actionType, title, lat, lon, timestamp
│   │   └── SimulationConfig.swift                    # Struct Sendable : speedMetersPerSecond, accuracy, altitude, loopRoute
│   ├── ViewModels/
│   │   ├── DashboardViewModel.swift                  # Logique de carte, sélection, télémétrie en direct
│   │   ├── RouteSimulationViewModel.swift            # Contrôle du lecteur d'itinéraire (Play, Pause, Stop, Vitesse, Progression)
│   │   └── SearchViewModel.swift                     # Debounce de recherche, autocomplétion, historique
│   └── Views/
│       ├── MainTabView.swift                         # Navigation principale (Dashboard, Itinéraires, Favoris, Historique, Réglages)
│       ├── Dashboard/
│       │   ├── DashboardView.swift                   # Carte plein écran + HUD télémétrique + tiroir de contrôle
│       │   ├── TelemetryHUDView.swift                # Affichage temps réel Lat/Lon/Alt/Précision/Cap/Ville/Source
│       │   └── QuickSimulationSheet.swift            # Saisie manuelle de coordonnées, altitude et précision
│       ├── Search/
│       │   └── LocationSearchView.swift              # Barre de recherche, suggestions temps réel, actions rapides
│       ├── Routes/
│       │   ├── RoutePlannerView.swift                # Création d'itinéraire (Départ, Étapes, Arrivée), tracé MapPolyline
│       │   └── RoutePlayerControlBar.swift           # Contrôles Play/Pause/Stop, sélecteur de vitesse, export GPX
│       ├── Favorites/
│       │   └── FavoritesListView.swift               # CRUD SwiftData, recherche, filtrage, lancement rapide de simulation
│       ├── History/
│       │   └── HistoryListView.swift                 # Journal d'activité horodaté, suppression unitaire/totale, restauration
│       └── Settings/
│           ├── SettingsView.swift                    # Thème, Unités (Métrique/Impérial), Langue, Purge SwiftData
│           └── XcodeGuideView.swift                  # Guide interactif intégré (Sideloading + GPX Xcode)
└── Tests/
    └── GeoShiftTests/
        ├── GeoMathTests.swift                        # Tests unitaires Haversine, cap, interpolation, validation coordonnées
        ├── SimulationEngineTests.swift               # Tests du SimulatedLocationProvider et transitions d'état
        └── GPXExporterTests.swift                    # Vérification de la conformité XML GPX générée
```

---

## 5. Guide d'Installation par Sideloading (Compte Apple Gratuit)

### Option 1 : Sideloadly (Recommandé sur Windows & Mac)
1. Téléchargez et installez **[Sideloadly](https://sideloadly.io/)**.
2. Récupérez le fichier **`GeoShift-Sideload.ipa`** (téléchargé depuis GitHub Actions ou généré localement).
3. Connectez votre iPhone par câble USB à votre ordinateur.
4. Glissez-déposez le fichier `.ipa` dans la fenêtre de Sideloadly.
5. Renseignez votre **Apple ID gratuit** personnel dans le champ `Apple ID`.
6. Cliquez sur **Start** pour lancer la signature et l'installation.
7. Sur votre iPhone :
   - Rendez-vous dans `Réglages > Confidentialité et sécurité > Mode développeur` et activez-le (l'appareil redémarre).
   - Rendez-vous dans `Réglages > Général > VPN et gestion des appareils`, touchez votre identifiant Apple et sélectionnez **Faire confiance**.

### Option 2 : AltStore & SideStore (Installation & Rafraîchissement Wi-Fi)
1. Téléchargez le fichier `GeoShift-Sideload.ipa` sur votre iPhone (via Safari ou l'application Fichiers).
2. Ouvrez **AltStore** ou **SideStore** sur votre iPhone.
3. Rendez-vous dans l'onglet **My Apps**, touchez le bouton `+` en haut à gauche et sélectionnez `GeoShift-Sideload.ipa`.
4. L'application est installée et signée pour 7 jours avec rafraîchissement automatique en arrière-plan par Wi-Fi.

### Option 3 : TrollStore (iOS 15.0 - 17.0)
Si votre appareil dispose de **TrollStore** :
1. Partagez `GeoShift-Sideload.ipa` vers TrollStore.
2. L'application est installée de façon permanente sans aucune limite de 7 jours ni besoin de resignature.

---

## 6. Accès aux Tracés GPX via l'Application "Fichiers" iOS

GeoShift a la clé `UIFileSharingEnabled` activée. Tout fichier `.gpx` créé ou exporté est automatiquement synchronisé dans le stockage local accessible de l'iPhone :
- Ouvrez l'application native **Fichiers** sur iOS.
- Rendez-vous dans **Sur mon iPhone > GeoShift**.
- Vous y trouverez l'ensemble de vos fichiers `.gpx`.
- En branchant l'iPhone à un PC (via iTunes / Apple Devices / Finder), vous pouvez copier directement ces fichiers d'un simple glisser-déposer.

---

## 7. Pilotage du GPS Système via Apple Xcode

Pour simuler le déplacement au niveau du système d'exploitation iOS :
1. Ouvrez votre projet de développement iOS sur Xcode (Mac).
2. Glissez votre fichier `.gpx` généré par GeoShift dans l'arborescence de votre projet.
3. Dans `Product > Scheme > Edit Scheme... > Run > Options`, cochez **Simulate Location** et sélectionnez votre fichier GPX.
4. Lancez votre application sur votre iPhone en USB ou Wi-Fi : Xcode interpolera la vitesse exactement selon les balises calculées par GeoShift !

---

## 8. Compilation du Projet

### Sur macOS (Local)
```bash
# 1. Génération du projet Xcode
xcodegen generate

# 2. Lancement des tests unitaires
xcodebuild test -project GeoShift.xcodeproj -scheme GeoShiftTests -destination 'platform=iOS Simulator,name=iPhone 16'

# 3. Génération de l'archive IPA Sideloadable
chmod +x scripts/build_sideload_ipa.sh
./scripts/build_sideload_ipa.sh
```

### Depuis Windows / Linux (via GitHub Actions)
1. Poussez votre code sur votre dépôt GitHub (`git push origin master`).
2. Ouvrez l'onglet **Actions** de votre dépôt GitHub.
3. Le workflow **`Build Sideloadable IPA (Free Apple ID Ready)`** s'exécute automatiquement et publie l'artefact **`GeoShift-Sideload-IPA`** téléchargeable directement.
