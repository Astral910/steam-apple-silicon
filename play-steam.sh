#!/bin/bash
# Launcher de Steam — se auto-actualiza y reintenta la conexión automáticamente.
# No cierres esta ventana hasta que Steam abra.

REPO_RAW="https://raw.githubusercontent.com/Astral910/steam-apple-silicon/main"
APP_NAME="SteamMac"
WRAPPER_DIR="$HOME/Applications/Sikarugir"
WRAPPER="$WRAPPER_DIR/$APP_NAME.app"
VERSION_FILE="$WRAPPER_DIR/.play-steam-version"
SELF="$WRAPPER_DIR/play-steam.sh"
MAX_INTENTOS=15

# --- Auto-actualización (silenciosa, no bloquea si no hay internet) ---
REMOTE_VERSION=$(curl -fsSL --max-time 5 "$REPO_RAW/VERSION" 2>/dev/null || echo "")
LOCAL_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "0")
if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
  echo "Actualizando el launcher a la versión $REMOTE_VERSION..."
  if curl -fsSL --max-time 10 -o "$SELF.new" "$REPO_RAW/play-steam.sh"; then
    chmod +x "$SELF.new"
    mv "$SELF.new" "$SELF"
    echo "$REMOTE_VERSION" > "$VERSION_FILE"
    exec "$SELF"
  fi
fi

if [ ! -d "$WRAPPER" ]; then
  echo "❌ No encuentro la instalación de Steam en $WRAPPER"
  echo "Corre el instalador primero: curl -fsSL $REPO_RAW/install.sh | bash"
  exit 1
fi

# --- Verificar/conectar WARP (necesario para que Steam no falle al conectar) ---
if ! command -v warp-cli &>/dev/null; then
  echo "❌ Cloudflare WARP no está instalado. Corre el instalador de nuevo."
  exit 1
fi
if ! warp-cli status 2>/dev/null | grep -q "Connected"; then
  echo "Conectando VPN necesaria..."
  warp-cli connect >/dev/null 2>&1
  sleep 3
fi

# --- Lanzar Steam con reintentos automáticos ---
WINEBIN="$WRAPPER/Contents/SharedSupport/wine/bin/wine"
PREFIX="$WRAPPER/Contents/SharedSupport/prefix"
FRAMEWORKS="$WRAPPER/Contents/Frameworks"
LOGDIR="$PREFIX/drive_c/Program Files (x86)/Steam/logs"
CONNLOG="$LOGDIR/connection_log.txt"

pkill -9 -f "steam\.exe " 2>/dev/null
pkill -9 -f "steamwebhelper.exe" 2>/dev/null
sleep 2

TRANSPORTLOG="$LOGDIR/transport_client.txt"

for i in $(seq 1 $MAX_INTENTOS); do
  echo "Abriendo Steam (intento $i de $MAX_INTENTOS)..."
  LINEAS_ANTES=$(wc -l < "$CONNLOG" 2>/dev/null || echo 0)
  TRANSPORT_LINEAS_ANTES=$(wc -l < "$TRANSPORTLOG" 2>/dev/null || echo 0)

  env WINEPREFIX="$PREFIX" DYLD_FALLBACK_LIBRARY_PATH="$FRAMEWORKS" DYLD_LIBRARY_PATH="$FRAMEWORKS" \
    "$WINEBIN" "C:\\Program Files (x86)\\Steam\\steam.exe" >/dev/null 2>&1 &
  WINEPID=$!

  sleep 40

  if tail -n +"$((LINEAS_ANTES + 1))" "$CONNLOG" 2>/dev/null | grep -q "Logged On"; then
    echo ""
    echo "✅ ¡Steam conectado! Ya puedes jugar."
    exit 0
  fi

  # Si el proceso de Steam sigue vivo y no vemos el bug conocido de "conexión
  # rechazada", lo dejamos abierto tal cual — probablemente solo está esperando
  # a que inicies sesión manualmente. Matarlo aquí interrumpiría tu login.
  SIGUE_VIVO=$(pgrep -f "steam\.exe " | head -1)
  HUBO_RECHAZO=$(tail -n +"$((TRANSPORT_LINEAS_ANTES + 1))" "$TRANSPORTLOG" 2>/dev/null | grep -c "Connection rejected")

  if [ -n "$SIGUE_VIVO" ] && [ "${HUBO_RECHAZO:-0}" -eq 0 ]; then
    echo ""
    echo "Steam sigue abierto. Si te pide iniciar sesión, hazlo en la ventana que se abrió."
    exit 0
  fi

  echo "No conectó, reintentando..."
  pkill -9 -f "steam\.exe " 2>/dev/null
  pkill -9 -f "steamwebhelper.exe" 2>/dev/null
  sleep 2
done

echo ""
echo "⚠️  No se logró conectar después de $MAX_INTENTOS intentos."
echo "Intenta abrir este launcher de nuevo en unos minutos, o revisa tu conexión a internet."
