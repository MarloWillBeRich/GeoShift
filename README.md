# GeoShift — iOS Native GPS Simulation & Route Engine

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0%2B-blue?style=for-the-badge&logo=apple" alt="iOS 17.0+">
  <img src="https://img.shields.io/badge/Swift-6.0%20Strict%20Concurrency-orange?style=for-the-badge&logo=swift" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20MapKit-purple?style=for-the-badge" alt="SwiftUI + MapKit">
  <img src="https://img.shields.io/badge/Persistence-SwiftData-green?style=for-the-badge" alt="SwiftData">
  <img src="https://img.shields.io/badge/XcodeGen-Ready-red?style=for-the-badge" alt="XcodeGen Ready">
</p>

---

## 1. Vue d'Ensemble & Vision Architecturale

**GeoShift** est une application iOS native de qualité industrielle conçue selon les plus hauts standards d'ingénierie logicielle Apple. Elle combine un moteur physique d'interpolation de télémétrie GPS en temps réel, un planificateur d'itinéraires multi-étapes propulsé par `MKDirections`, une persistance réactive `SwiftData` et un exportateur universel **GPX 1.1** optimisé pour l'injection directe dans les outils de débogage officiels d'Apple (**Xcode Simulate Location**).

### Règle d'Intégrité Système & Conformité Sandbox Apple
Sur les appareils iOS officiels (non-jailbreakés), le bac à sable de sécurité (App Sandbox) interdit formellement à une application tierce de modifier arbitrairement les coordonnées GPS globales du système pour les autres applications.
Pour répondre à cette contrainte tout en garantissant des capacités de simulation et de test de pointe pour les développeurs, GeoShift adopte une **double approche architecturale** :
1. **Moteur Interne Ultra-Précis (`LocationProviderProtocol`)** : L'interface utilisateur, la télémétrie et les calculs de progression fonctionnent sur une abstraction découplée capable de basculer instantanément entre le récepteur GPS matériel (`RealLocationProvider`) et un moteur d'interpolation physique (`SimulatedLocationProvider`).
2. **Générateur & Pont GPX Xcode (`GPXExporter`)** : GeoShift calcule la cinématique du déplacement (vitesse en m/s et temps de passage) et produit un fichier XML GPX 1.1 muni de balises `<wpt>` horodatées séquentiellement. Ce fichier peut être exporté via AirDrop vers un Mac pour piloter la simulation de localisation officielle de Xcode lors d'une session de développement USB ou Wi-Fi.

---

## 2. Fonctionnalités Clés

- **Télémétrie en Direct (HUD)** : Surveillance à haute fréquence de la Latitude, Longitude, Altitude, Cap (Course avec rose des vents), Vitesse instantanée et Précision horizontale avec typographie monospacée (`.monospacedDigit()`) évitant tout tressautement d'affichage.
- **Indicateur de Source Explicite** : Badge visuel dynamique distinguant `MATÉRIEL (GPS Réel)` de `SIMULATION LOCALE (Sandbox)`.
- **Interpolation Physique Réaliste** : Déplacement cinématique le long des polylignes routières calculées par `MKDirections` avec micro-bruit GPS réglable (jitter gaussien) et profils de vitesse prédéfinis (Marche, Course, Vélo, Ville, Autoroute, TGV).
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
├── project.yml                                  # Configuration XcodeGen (iOS 17+, Swift 6, Info.plist)
├── .github/workflows/ios-build.yml              # Pipeline CI GitHub Actions (macOS, Xcode 16, build IPA)
├── README.md                                    # Spécifications, architecture et guide d'utilisation
├── scripts/
│   └── build_ipa.sh                            # Script bash de compilation et empaquetage IPA
├── Resources/
│   ├── Info.plist                               # Déclarations NSLocation, autorisations et background modes
│   └── DemoRoute_Paris.gpx                      # Fichier GPX de démonstration officiel Xcode
├── Sources/
│   ├── App/
│   │   ├── GeoShiftApp.swift                    # Point d'entrée @main et injection ModelContainer SwiftData
│   │   └── AppState.swift                       # État global réactif @Observable @MainActor
│   ├── Core/
│   │   ├── DesignSystem/
│   │   │   ├── Theme.swift                      # Charte graphique hexadécimale, modifieurs et styles
│   │   │   └── TelemetryBadge.swift             # Badges de statut GPS, pilules télémétriques monospacées
│   │   ├── Location/
│   │   │   ├── LocationProviderProtocol.swift   # Abstraction TelemetrySnapshot et protocole unifié
│   │   │   ├── RealLocationProvider.swift       # Wrapper CLLocationManager en AsyncStream
│   │   │   ├── SimulatedLocationProvider.swift  # Moteur physique d'interpolation et boucle ContinuousClock
│   │   │   └── LocationEngine.swift             # Orchestrateur de basculement + Reverse Geocoding régulé
│   │   ├── Map/
│   │   │   ├── GeoMath.swift                    # Formules pures Swift : Haversine, Cap, Destination, Jitter
│   │   │   ├── MapSearchService.swift           # Autocomplétion MKLocalSearchCompleter async/await
│   │   │   └── RouteCalculatorService.swift     # Calcul de routes multi-étapes via MKDirections
│   │   └── Utilities/
│   │       ├── GPXExporter.swift                # Moteur de sérialisation XML GPX 1.1 horodaté séquentiellement
│   │       └── CoordinateFormatter.swift        # Formatage DMS / Décimal et analyse syntaxique
│   ├── Models/
│   │   ├── FavoriteLocation.swift               # @Model SwiftData : lieux clés organisés par catégorie
│   │   ├── SavedRoute.swift                     # @Model SwiftData : polylignes et jalons d'itinéraires
│   │   ├── HistoryEntry.swift                   # @Model SwiftData : journal d'audit télémétrique horodaté
│   │   └── SimulationConfig.swift               # Struct Sendable : vitesse, précision, bruit GPS et boucle
│   ├── ViewModels/
│   │   ├── DashboardViewModel.swift             # Gestion de la caméra MapKit iOS 17 et épingles manuelles
│   │   ├── RouteSimulationViewModel.swift       # Contrôle de la simulation routière et export GPX
│   │   └── SearchViewModel.swift                # Filtrage, autocomplétion et détection de coordonnées directes
│   └── Views/
│       ├── MainTabView.swift                    # Navigation TabView personnalisée + bannières Toast
│       ├── Dashboard/
│       │   ├── DashboardView.swift              # Carte plein écran MapKit iOS 17 + marqueurs personnalisés
│       │   ├── TelemetryHUDView.swift           # Affichage tête haute temps réel repliable
│       │   └── QuickSimulationSheet.swift       # Saisie de coordonnées manuelles et préréglages mondiaux
│       ├── Search/
│       │   └── LocationSearchView.swift         # Interface de recherche avec suggestions et puces rapides
│       ├── Routes/
│       │   ├── RoutePlannerView.swift           # Éditeur d'itinéraire multi-points et affichage MapPolyline
│       │   └── RoutePlayerControlBar.swift      # Contrôles de lecture Play/Pause/Stop, curseur et vitesse
│       ├── Favorites/
│       │   └── FavoritesListView.swift          # CRUD SwiftData complet avec filtres par catégorie
│       ├── History/
│       │   └── HistoryListView.swift            # Journal chronologique avec restauration rapide de position
│       └── Settings/
│           ├── SettingsView.swift               # Réglages des unités, haptique, style de carte et purge
│           └── XcodeGuideView.swift             # Documentation interactive intégrée du pont Xcode GPX
└── Tests/
    └── GeoShiftTests/
        ├── GeoMathTests.swift                   # Tests unitaires géodésiques (Haversine, Cap, Interpolation)
        ├── SimulationEngineTests.swift          # Tests du cycle de vie et des états du SimulatedLocationProvider
        └── GPXExporterTests.swift               # Validation de conformité XML GPX et horodatage séquentiel
```

---

## 5. Guide de Compilation & Déploiement

### Option A : Compilation Locale sur macOS (avec Xcode)

1. **Installer XcodeGen** (si nécessaire) :
   ```bash
   brew install xcodegen
   ```
2. **Générer le projet `.xcodeproj`** :
   ```bash
   xcodegen generate
   ```
3. **Ouvrir le projet dans Xcode** :
   ```bash
   open GeoShift.xcodeproj
   ```
4. **Lancer les tests unitaires** :
   ```bash
   xcodebuild test -project GeoShift.xcodeproj -scheme GeoShiftTests -destination 'platform=iOS Simulator,name=iPhone 16'
   ```
5. **Générer automatiquement le binaire IPA non signé** :
   ```bash
   chmod +x scripts/build_ipa.sh
   ./scripts/build_ipa.sh
   ```
   Le fichier `build/GeoShift_unsigned.ipa` sera produit et prêt pour l'installation.

### Option B : Compilation depuis Windows / Linux via GitHub Actions

Si vous développez sur un poste de travail sous Windows ou Linux, le workflow automatisé `.github/workflows/ios-build.yml` compile l'application sur les serveurs macOS de GitHub :
1. Poussez le dépôt sur votre compte GitHub (`git push origin main`).
2. Rendez-vous dans l'onglet **Actions** de votre dépôt.
3. Le workflow `iOS Build & IPA Generation` s'exécute automatiquement, exécute les tests unitaires et produit l'artefact téléchargeable **`GeoShift-iOS-IPA`** contenant l'archive `.ipa` prête à l'emploi.

---

## 6. Guide Pratique : Simuler la Localisation avec Xcode

Pour répercuter les simulations de GeoShift sur l'ensemble du système iOS lors du développement d'applications :

1. **Création du parcours** : Dans l'onglet **Itinéraires** de GeoShift, définissez vos étapes et réglez la vitesse souhaitée.
2. **Exportation du GPX** : Touchez le bouton **GPX** pour exporter le fichier généré vers votre Mac via AirDrop ou partage de fichiers.
3. **Import dans Xcode** : Glissez le fichier `.gpx` dans votre projet iOS dans Xcode.
4. **Activation de la simulation** :
   - Rendez-vous dans `Product > Scheme > Edit Scheme...`
   - Sélectionnez l'action **Run** puis l'onglet **Options**.
   - Cochez **Simulate Location** et sélectionnez votre fichier GPX.
5. **Exécution en direct** : Lorsque vous exécutez votre application sur votre iPhone (relié par câble USB ou Wi-Fi), Xcode anime automatiquement les coordonnées GPS globales du système au rythme précis calculé par GeoShift.

---

## 7. Installation de l'IPA (Sideloading)

L'archive `GeoShift_unsigned.ipa` peut être installée directement sur n'importe quel iPhone sous iOS 17.0+ en utilisant l'un des outils de signature tiers suivants :
- **AltStore / AltServer**
- **SideStore**
- **Sideloadly**
- **LiveContainer / TrollStore** (selon version d'iOS)

---

## 8. Conformité & Qualité de Code
- **Zero-Placeholder Policy** : 100 % du code source est écrit, documenté et immédiatement compilable.
- **Swift 6 Strict Concurrency** : Toutes les classes et structs respectent les frontières d'isolation d'acteurs (`@MainActor`, `Sendable`).
- **SwiftData Best Practices** : Gestion transactionnelle avec `ModelContainer` et requêtes déclaratives `@Query`.
