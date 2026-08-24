#!/bin/bash
# Instalador de Steam para Mac con Apple Silicon (M1-M5), vía Wine (Sikarugir) + D3DMetal.
# Uso: curl -fsSL https://raw.githubusercontent.com/Astral910/steam-apple-silicon/main/install.sh | bash
set -e

REPO_RAW="https://raw.githubusercontent.com/Astral910/steam-apple-silicon/main"
APP_NAME="SteamMac"
WRAPPER_DIR="$HOME/Applications/Sikarugir"
WRAPPER="$WRAPPER_DIR/$APP_NAME.app"
TEMPLATE_URL="https://github.com/Sikarugir-App/Wrapper/releases/download/v1.0/Template-1.0.11.tar.xz"
ENGINE_URL="https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineCX24.0.7_7.tar.xz"
STEAM_URL="https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"

echo "=========================================="
echo " Instalador de Steam para Apple Silicon"
echo "=========================================="
echo ""

# --- 1. Verificar Apple Silicon ---
if [ "$(uname -m)" != "arm64" ]; then
  echo "❌ Este instalador es solo para Macs con Apple Silicon (M1-M5). Tu Mac no es compatible."
  exit 1
fi
echo "✅ Apple Silicon detectado ($(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'arm64'))"

# --- 2. Homebrew ---
if ! command -v brew &>/dev/null; then
  echo ""
  echo "⚠️  Vas a necesitar tu contraseña de Mac para instalar Homebrew (gestor de paquetes)."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
echo "✅ Homebrew listo"

# --- 3. Cloudflare WARP (necesario: sin esto, Steam falla al conectar bajo Wine) ---
if ! command -v warp-cli &>/dev/null; then
  echo ""
  echo "⚠️  Vas a necesitar tu contraseña de Mac otra vez para instalar Cloudflare WARP."
  brew install --cask cloudflare-warp
fi
echo "✅ Cloudflare WARP instalado"

echo "Registrando y conectando WARP..."
warp-cli registration new >/dev/null 2>&1 || true
warp-cli connect >/dev/null 2>&1 || true
sleep 3
echo "✅ WARP conectado"

# --- 4. Crear el wrapper (Template + motor CrossOver 24) ---
echo ""
echo "Creando el entorno de Steam (esto puede tardar varios minutos, se descargan ~500MB)..."
mkdir -p "$WRAPPER_DIR"
TMP=$(mktemp -d)

curl -fsSL -o "$TMP/template.tar.xz" "$TEMPLATE_URL"
tar -xJf "$TMP/template.tar.xz" -C "$TMP"
rm -rf "$WRAPPER"
mv "$TMP/Template-1.0.11.app" "$WRAPPER"

echo "Descargando el motor gráfico (CrossOver 24)..."
curl -fsSL -o "$TMP/engine.tar.xz" "$ENGINE_URL"
tar -xJf "$TMP/engine.tar.xz" -C "$WRAPPER/Contents/SharedSupport"
mv "$WRAPPER/Contents/SharedSupport/wswine.bundle" "$WRAPPER/Contents/SharedSupport/wine"
echo "✅ Entorno creado"

# --- 5. Inicializar el prefix y configurar D3DMetal ---
echo ""
echo "Configurando gráficos y rendimiento..."
WINEBIN="$WRAPPER/Contents/SharedSupport/wine/bin/wine"
PREFIX="$WRAPPER/Contents/SharedSupport/prefix"
FRAMEWORKS="$WRAPPER/Contents/Frameworks"

env WINEPREFIX="$PREFIX" DYLD_FALLBACK_LIBRARY_PATH="$FRAMEWORKS" DYLD_LIBRARY_PATH="$FRAMEWORKS" \
  "$WINEBIN" wineboot -u >/dev/null 2>&1

PLIST="$WRAPPER/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :D3DMETAL 1" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :WINEESYNC 1" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :WINEMSYNC 1" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$PLIST"
echo "✅ D3DMetal activado"

# --- 6. Instalar Steam ---
echo ""
echo "Descargando e instalando Steam..."
curl -fsSL -o "$TMP/SteamSetup.exe" "$STEAM_URL"
WIN_TMP="Z:$(echo "$TMP" | sed 's#/#\\#g')"

env WINEPREFIX="$PREFIX" DYLD_FALLBACK_LIBRARY_PATH="$FRAMEWORKS" DYLD_LIBRARY_PATH="$FRAMEWORKS" \
  "$WINEBIN" "$WIN_TMP\\SteamSetup.exe" /S >/dev/null 2>&1 &

for i in $(seq 1 60); do
  if [ -f "$PREFIX/drive_c/Program Files (x86)/Steam/steam.exe" ]; then break; fi
  sleep 2
done
sleep 5
echo "✅ Steam instalado"

/usr/libexec/PlistBuddy -c 'Set "Program Name and Path" "/Program Files (x86)/Steam/steam.exe"' "$PLIST"

# --- 7. Primer arranque (deja que Steam baje su actualización inicial de una vez) ---
echo ""
echo "Preparando Steam por primera vez (puede tardar unos minutos, es solo esta vez)..."
pkill -9 -f "steam\.exe " 2>/dev/null || true
"$WRAPPER/Contents/MacOS/WineskinLauncher" >/dev/null 2>&1 &
sleep 90
pkill -9 -f "steam\.exe " 2>/dev/null || true
pkill -9 -f "steamwebhelper.exe" 2>/dev/null || true
sleep 2
echo "✅ Listo"

# --- 8. Instalar el launcher para jugar ---
echo ""
echo "Instalando el launcher..."
curl -fsSL -o "$WRAPPER_DIR/play-steam.sh" "$REPO_RAW/play-steam.sh"
chmod +x "$WRAPPER_DIR/play-steam.sh"
curl -fsSL -o "$WRAPPER_DIR/Play Steam.command" "$REPO_RAW/Play Steam.command"
chmod +x "$WRAPPER_DIR/Play Steam.command"
curl -fsSL -o "$WRAPPER_DIR/.play-steam-version" "$REPO_RAW/VERSION" 2>/dev/null || echo "1" > "$WRAPPER_DIR/.play-steam-version"

rm -rf "$TMP"

echo ""
echo "=========================================="
echo "✅ ¡Instalación completa!"
echo ""
echo "Para jugar, abre este archivo (doble clic en Finder):"
echo "  $WRAPPER_DIR/Play Steam.command"
echo ""
echo "La primera vez tendrás que iniciar sesión en tu cuenta de Steam manualmente."
echo "=========================================="
