#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GeoShift — Script de Construction & Génération d'Archive IPA (macOS / Xcode)
# ==============================================================================

echo "🚀 [GeoShift] Démarrage du script de compilation..."

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/GeoShift.xcarchive"
PAYLOAD_DIR="$BUILD_DIR/Payload"
EXPORT_OPTIONS_PATH="$BUILD_DIR/ExportOptions.plist"
OUTPUT_IPA="$BUILD_DIR/GeoShift.ipa"
UNSIGNED_IPA="$BUILD_DIR/GeoShift_unsigned.ipa"

mkdir -p "$BUILD_DIR"

# 1. Vérification de l'environnement XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "⚠️  XcodeGen n'est pas détecté. Tentative d'installation via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "❌ Erreur : Veuillez installer xcodegen (brew install xcodegen) ou générer le projet sur macOS."
        exit 1
    fi
fi

# 2. Génération du projet .xcodeproj
echo "🛠️  Génération de GeoShift.xcodeproj via XcodeGen..."
xcodegen generate

# 3. Création du fichier ExportOptions.plist pour export de développement
cat <<EOF > "$EXPORT_OPTIONS_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

# 4. Compilation de l'archive Release via xcodebuild
echo "📦 Compilation de l'archive Release iOS..."
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
    -project GeoShift.xcodeproj \
    -scheme GeoShift \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO

# 5. Création du package .ipa universel (compatible AltStore, SideStore, Sideloadly)
echo "📦 Empaquetage du binaire dans l'archive IPA..."
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"

APP_PATH="$ARCHIVE_PATH/Products/Applications/GeoShift.app"

if [ -d "$APP_PATH" ]; then
    cp -R "$APP_PATH" "$PAYLOAD_DIR/"
    cd "$BUILD_DIR"
    zip -q -r -y "GeoShift_unsigned.ipa" "Payload"
    rm -rf "Payload"
    cd "$PROJECT_DIR"
    echo "✅ Archive IPA non signée générée : $UNSIGNED_IPA"
else
    echo "❌ Erreur : Binaire GeoShift.app introuvable dans l'archive !"
    exit 1
fi

echo "🎉 [GeoShift] Processus de build terminé avec succès !"
ls -lh "$BUILD_DIR"
