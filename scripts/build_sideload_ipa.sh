#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GeoShift — Script de Build Release Sideloadable (.IPA Universel)
# Compatible : Sideloadly, AltStore, SideStore, Feather, TrollStore
# ==============================================================================

echo "🚀 [GeoShift Sideload] Démarrage du pipeline de compilation..."

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/GeoShift.xcarchive"
PAYLOAD_DIR="$BUILD_DIR/Payload"
SIDELOAD_IPA="$BUILD_DIR/GeoShift-Sideload.ipa"

mkdir -p "$BUILD_DIR"

# 1. Vérification & Génération du projet Xcode via XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "⚠️  XcodeGen n'est pas détecté. Tentative d'installation via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "❌ Erreur : XcodeGen requis (brew install xcodegen)."
        exit 1
    fi
fi

echo "🛠️  Génération du projet Xcode (GeoShift.xcodeproj)..."
xcodegen generate

# 2. Nettoyage des builds précédents
rm -rf "$ARCHIVE_PATH"
rm -rf "$PAYLOAD_DIR"
rm -f "$SIDELOAD_IPA"

# 3. Compilation Release pour architecture réelle arm64 (iphoneos)
echo "📦 Compilation Release de l'archive iOS sans certificat payant..."
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

# 4. Signature Ad-Hoc locale (requise pour intégrité binaire avant resignature tierce)
echo "🔏 Application de la signature Ad-Hoc..."
if command -v codesign &> /dev/null; then
    codesign --force --deep --sign - "$APP_SOURCE" 2>/dev/null || true
elif command -v ldid &> /dev/null; then
    ldid -S "$APP_SOURCE" 2>/dev/null || true
fi

# 5. Création de la structure Payload/ standard pour .ipa
echo "📂 Création de l'arborescence Payload..."
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_SOURCE" "$PAYLOAD_DIR/"

# 6. Compression ZIP au format .ipa
echo "📦 Génération de l'archive GeoShift-Sideload.ipa..."
cd "$BUILD_DIR"
zip -q -r -y "GeoShift-Sideload.ipa" "Payload"
rm -rf "Payload"

# Copie miroir vers GeoShift-Unsigned.ipa pour compatibilité maximale
cp -f "GeoShift-Sideload.ipa" "GeoShift-Unsigned.ipa"

cd "$PROJECT_DIR"

echo "✅ [GeoShift Sideload] Archive IPA générée avec succès !"
echo "📍 Emplacement : $SIDELOAD_IPA"
if command -v shasum &> /dev/null; then
    echo "🔒 SHA256 : $(shasum -a 256 "$SIDELOAD_IPA" | awk '{print $1}')"
fi
ls -lh "$BUILD_DIR"
