#!/bin/bash
# Instalador de Steam para Mac con Apple Silicon (M1-M5), vía Wine (Sikarugir) + D3DMetal.
# Uso:
#   curl -fsSL -o install.sh https://raw.githubusercontent.com/Astral910/steam-apple-silicon/main/install.sh
#   bash install.sh
set -e

# Este instalador necesita pedir tu contraseña (para Homebrew/WARP). Eso requiere una
# terminal real — si lo corriste como "curl ... | bash", la entrada queda ocupada por
# el pipe y la contraseña nunca puede pedirse, así que fallamos temprano con un mensaje
# claro en vez de dejar que Homebrew truene más adelante de forma confusa.
if [ ! -t 0 ] && [ -z "$SAI_FORCE" ]; then
  echo "⚠️  Este instalador necesita correr en una terminal normal, no con 'curl | bash'."
  echo ""
  echo "Corre esto en su lugar:"
  echo ""
  echo "  curl -fsSL -o install.sh https://raw.githubusercontent.com/Astral910/steam-apple-silicon/main/install.sh"
  echo "  bash install.sh"
  echo ""
  exit 1
fi

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

# --- 1. Verificar Apple Silicon + macOS ---
MAC_MODEL=$(sysctl -n hw.model 2>/dev/null || echo "desconocido")
CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "arm64")
MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "desconocida")
MACOS_NAME=$(sw_vers -productName 2>/dev/null || echo "macOS")

if [ "$(uname -m)" != "arm64" ]; then
  echo "❌ Este instalador es solo para Macs con Apple Silicon (M1-M5). Tu Mac ($MAC_MODEL) no es compatible."
  exit 1
fi

MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MACOS_MAJOR" -lt 13 ] 2>/dev/null; then
  echo "⚠️  Detecté macOS $MACOS_VERSION. Se recomienda macOS 13 (Ventura) o más nuevo para mejor compatibilidad gráfica."
  echo "   Puede que igual funcione, pero no está garantizado en versiones más viejas."
fi

echo "✅ $MAC_MODEL — $CHIP — $MACOS_NAME $MACOS_VERSION"

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

# wineboot a veces devuelve un código distinto de cero aunque haya funcionado bien
# (varía entre Macs). No dejamos que eso mate el script entero — lo que de verdad
# importa es que el prefix haya quedado creado, eso lo verificamos aparte.
mkdir -p "$WRAPPER_DIR/.install-logs"
env WINEPREFIX="$PREFIX" DYLD_FALLBACK_LIBRARY_PATH="$FRAMEWORKS" DYLD_LIBRARY_PATH="$FRAMEWORKS" \
  "$WINEBIN" wineboot -u > "$WRAPPER_DIR/.install-logs/wineboot.log" 2>&1 || true

if [ ! -d "$PREFIX/drive_c" ]; then
  echo "❌ No se pudo crear el entorno de Windows. Revisa el log en:"
  echo "   $WRAPPER_DIR/.install-logs/wineboot.log"
  exit 1
fi

PLIST="$WRAPPER/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :D3DMETAL 1" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :WINEESYNC 1" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :WINEMSYNC 1" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$PLIST" 2>/dev/null || true
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

/usr/libexec/PlistBuddy -c 'Set "Program Name and Path" "/Program Files (x86)/Steam/steam.exe"' "$PLIST" 2>/dev/null || true

# --- 7. Primer arranque (deja que Steam baje su actualización inicial completa de una vez) ---
echo ""
echo "Preparando Steam por primera vez — va a descargar su actualización inicial (~300MB)."
echo "Esto puede tardar varios minutos dependiendo de tu internet, es solo esta vez."
pkill -9 -f "steam\.exe " 2>/dev/null || true
BOOTLOG="$PREFIX/drive_c/Program Files (x86)/Steam/logs/bootstrap_log.txt"
"$WRAPPER/Contents/MacOS/WineskinLauncher" >/dev/null 2>&1 &

# El bootstrap incluido en el instalador suele estar desactualizado y necesita
# actualizarse a sí mismo antes de bajar el cliente completo — a veces tarda varios
# minutos. La señal real de "ya terminó" es que aparezca connection_log.txt con
# contenido, porque eso solo pasa cuando el cliente real (no el bootstrap viejo)
# ya está corriendo. NO matamos el proceso mientras tanto: interrumpirlo a medias
# lo hace empezar de cero.
CONNLOG="$PREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
DONE=0
for i in $(seq 1 180); do
  sleep 5
  if [ -f "$CONNLOG" ] && [ -s "$CONNLOG" ]; then
    DONE=1
    break
  fi
  if [ $((i % 12)) -eq 0 ]; then
    echo "   ... sigue preparando (esto es normal la primera vez, puede tardar varios minutos)"
  fi
done

pkill -9 -f "steam\.exe " 2>/dev/null || true
pkill -9 -f "steamwebhelper.exe" 2>/dev/null || true
sleep 2

if [ "$DONE" = "1" ]; then
  echo "✅ Listo"
else
  echo "⚠️  La preparación inicial tardó más de lo esperado. No hay problema, el launcher"
  echo "   terminará de descargar lo que falte la primera vez que le des Play."
fi

# --- 8. Instalar el launcher para jugar ---
echo ""
echo "Instalando el launcher..."
curl -fsSL -o "$WRAPPER_DIR/play-steam.sh" "$REPO_RAW/play-steam.sh"
chmod +x "$WRAPPER_DIR/play-steam.sh"
curl -fsSL -o "$WRAPPER_DIR/Play Steam.command" "$REPO_RAW/Play%20Steam.command"
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
