#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GeoShift — Script de Build Release IPA Non Signé (macOS / Xcode)
# Destiné à être signé ultérieurement par Sideloadly / AltStore
# ==============================================================================

echo "🚀 [GeoShift] Démarrage du pipeline de compilation Release..."

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/GeoShift.xcarchive"
PAYLOAD_DIR="$BUILD_DIR/Payload"
UNSIGNED_IPA="$BUILD_DIR/GeoShift-Unsigned.ipa"

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

# 3. Nettoyage des builds précédents
rm -rf "$ARCHIVE_PATH"
rm -rf "$PAYLOAD_DIR"
rm -f "$UNSIGNED_IPA"

# 4. Compilation de l'archive Release via xcodebuild
echo "📦 Compilation de l'archive Release iOS..."
xcodebuild archive \
    -project GeoShift.xcodeproj \
    -scheme GeoShift \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO

APP_SOURCE="$ARCHIVE_PATH/Products/Applications/GeoShift.app"

if [ ! -d "$APP_SOURCE" ]; then
    echo "❌ Erreur critique : Binaire GeoShift.app introuvable dans l'archive : $APP_SOURCE"
    exit 1
fi

# 5. Contrôle du Bundle Identifier
INFO_PLIST="$APP_SOURCE/Info.plist"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || defaults read "$PWD/$INFO_PLIST" CFBundleIdentifier)
echo "📋 Bundle ID détecté : $BUNDLE_ID"
if [ "$BUNDLE_ID" != "com.geoshift.app" ]; then
    echo "❌ Erreur critique : Le Bundle ID est '$BUNDLE_ID', attendu 'com.geoshift.app' !"
    exit 1
fi

# 6. Création du package .ipa non signé
echo "📦 Empaquetage du binaire dans l'archive IPA non signée..."
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_SOURCE" "$PAYLOAD_DIR/"

cd "$BUILD_DIR"
zip -q -r -y "GeoShift-Unsigned.ipa" "Payload"
rm -rf "Payload"
cd "$PROJECT_DIR"

if [ ! -f "$UNSIGNED_IPA" ]; then
    echo "❌ Erreur critique : L'archive IPA non signée n'a pas pu être créée !"
    exit 1
fi

echo "🔍 Vérification de la structure Payload/GeoShift.app..."
unzip -l "$UNSIGNED_IPA" | grep -E "Payload/GeoShift.app/GeoShift$" || {
    echo "❌ Erreur critique : La structure Payload/GeoShift.app est invalide !"
    exit 1
}

echo "✅ [GeoShift] Archive IPA non signée générée avec succès : $UNSIGNED_IPA"
if command -v shasum &> /dev/null; then
    echo "🔒 SHA256 : $(shasum -a 256 "$UNSIGNED_IPA" | awk '{print $1}')"
fi
ls -lh "$UNSIGNED_IPA"
