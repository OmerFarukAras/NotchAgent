#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
    echo "Hata: Lütfen uygulamanın yolunu belirtin."
    echo "Kullanım: ./scripts/create_dmg.sh /path/to/NotchAgent.app"
    exit 1
fi

APP_PATH="$1"

if [ ! -d "$APP_PATH" ]; then
    echo "Hata: Belirtilen yolda bir uygulama bulunamadı: $APP_PATH"
    exit 1
fi

APP_NAME=$(basename "$APP_PATH" .app)
OUTPUT_DIR=$(dirname "$APP_PATH")
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
DMG_STAGING="${OUTPUT_DIR}/dmg_staging"

echo ">>> '$APP_PATH' için sürükle-bırak DMG oluşturuluyor..."

# Eski dosyaları temizle
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"

# Uygulamayı DMG hazırlık klasörüne kopyala
echo ">>> Uygulama kopyalanıyor..."
cp -R "$APP_PATH" "$DMG_STAGING/"

# Sürükle bırak işlemi için Applications (Uygulamalar) kısayolu oluştur
echo ">>> Applications kısayolu oluşturuluyor..."
ln -s /Applications "$DMG_STAGING/Applications"

# hdiutil ile DMG paketini oluştur
echo ">>> Disk imajı (DMG) paketleniyor..."
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"

# Hazırlık klasörünü sil
rm -rf "$DMG_STAGING"

echo ">>> BAŞARILI! DMG dosyanız hazır: $DMG_PATH"
