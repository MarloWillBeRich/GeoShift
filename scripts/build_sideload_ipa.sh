#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GeoShift — Script de Build Release IPA Non Signé (macOS)
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

# 1. Vérification & Génération du projet Xcode via XcodeGen
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"
if ! command -v xcodegen &> /dev/null; then
    echo "⚠️  XcodeGen n'est pas détecté. Installation rapide depuis GitHub Release 2.47.0..."
    curl -Ls https://github.com/yonaskolb/XcodeGen/releases/download/2.47.0/xcodegen.zip -o /tmp/xcodegen.zip
    unzip -q /tmp/xcodegen.zip -d /tmp
    sudo /tmp/xcodegen/install.sh 2>/dev/null || {
        mkdir -p "$HOME/.local/bin"
        PREFIX="$HOME/.local" /tmp/xcodegen/install.sh
    }
    rm -rf /tmp/xcodegen.zip /tmp/xcodegen
fi
echo "XcodeGen version : $(xcodegen --version || true)"

echo "🛠️  Génération du projet Xcode (GeoShift.xcodeproj)..."
xcodegen generate

# 2. Nettoyage des builds précédents
rm -rf "$ARCHIVE_PATH"
rm -rf "$PAYLOAD_DIR"
rm -f "$UNSIGNED_IPA"

# 3. Compilation Release pour architecture réelle arm64 (iphoneos)
echo "📦 Compilation Release de l'archive iOS sans signature..."
xcodebuild archive \
    -project GeoShift.xcodeproj \
    -scheme GeoShift \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO

APP_SOURCE="$ARCHIVE_PATH/Products/Applications/GeoShift.app"

if [ ! -d "$APP_SOURCE" ]; then
    echo "❌ Erreur : Le binaire GeoShift.app n'a pas été produit dans $APP_SOURCE"
    exit 1
fi

# 4. Vérification du Bundle Identifier
INFO_PLIST="$APP_SOURCE/Info.plist"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || defaults read "$PWD/$INFO_PLIST" CFBundleIdentifier)
echo "📋 CFBundleIdentifier détecté : $BUNDLE_ID"
if [ "$BUNDLE_ID" != "com.geoshift.app" ]; then
    echo "❌ Erreur critique : Le Bundle ID est '$BUNDLE_ID', attendu 'com.geoshift.app' !"
    exit 1
fi

# 5. Création de la structure Payload/ standard pour .ipa
echo "📂 Création de l'arborescence Payload..."
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_SOURCE" "$PAYLOAD_DIR/"

# 6. Compression ZIP au format .ipa non signé
echo "📦 Génération de l'archive GeoShift-Unsigned.ipa..."
cd "$BUILD_DIR"
zip -q -r -y "GeoShift-Unsigned.ipa" "Payload"
rm -rf "Payload"

cd "$PROJECT_DIR"

if [ ! -f "$UNSIGNED_IPA" ]; then
    echo "❌ Erreur critique : L'archive IPA non signée n'a pas pu être générée !"
    exit 1
fi

echo "🔍 Vérification de la structure du fichier ZIP..."
unzip -l "$UNSIGNED_IPA" | grep -E "Payload/GeoShift.app/GeoShift$" || {
    echo "❌ Erreur critique : La structure Payload/GeoShift.app est invalide !"
    exit 1
}

echo "✅ [GeoShift] Archive IPA non signée générée avec succès !"
echo "📍 Emplacement : $UNSIGNED_IPA"
if command -v shasum &> /dev/null; then
    echo "🔒 SHA256 : $(shasum -a 256 "$UNSIGNED_IPA" | awk '{print $1}')"
fi
ls -lh "$UNSIGNED_IPA"
