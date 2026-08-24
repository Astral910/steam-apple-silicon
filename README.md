# Steam para Mac Apple Silicon (M1–M5)

Instala Steam en tu Mac con chip Apple Silicon usando un entorno de compatibilidad (Wine + D3DMetal), sin necesidad de Windows ni de una máquina virtual.

## Instalación (2 pasos)

**1.** Abre la app **Terminal** (Cmd+Espacio, escribe "Terminal") y pega esto (son 2 líneas, cópialas juntas):

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/Astral910/steam-apple-silicon/main/install.sh
bash install.sh
```

(No sirve hacerlo como `curl ... | bash` en un solo paso — necesita una terminal real para poder pedirte la contraseña.)

Te va a pedir tu contraseña de Mac dos veces (para instalar Homebrew y Cloudflare WARP — es normal, ambos son software real y necesario, no de este proyecto). La instalación completa tarda unos 10-15 minutos dependiendo de tu internet.

**2.** Cuando termine, abre (doble clic en Finder):

```
~/Applications/Sikarugir/Play Steam.command
```

La primera vez tendrás que iniciar sesión con tu cuenta de Steam manualmente. Después de eso, solo abre ese mismo archivo cada vez que quieras jugar.

## ¿Qué instala esto exactamente?

- [Cloudflare WARP](https://1.1.1.1/) — necesario porque sin esto, Steam falla intermitentemente al conectar bajo Wine (bug conocido, no relacionado con este proyecto)
- Un entorno Wine (motor CrossOver 24 de código abierto) con D3DMetal activado, para traducir gráficos DirectX a Metal de forma nativa en Apple Silicon
- Steam, instalado dentro de ese entorno

No requiere ni instala ningún contenido pirata ni cracks — solo Steam, tal cual lo distribuye Valve.

## Limitaciones conocidas

Este proyecto automatiza un setup basado en herramientas de código abierto en desarrollo activo. No es perfecto:

- **A veces Steam tarda varios intentos en conectar.** El launcher reintenta solo hasta 15 veces — es normal que tarde un par de intentos.
- **Cambiar de app (Cmd+Tab) mientras estás en un juego a veces congela el teclado/mouse.** Es un bug conocido y sin arreglo gratuito disponible en `winemac.drv` (el driver de Wine para macOS). Si pasa, cierra el juego desde el ícono del Dock y ábrelo de nuevo desde tu biblioteca de Steam.
- **Los juegos deben abrirse desde la biblioteca de Steam**, no ejecutando su `.exe` directo — si no, falla la integración con Steamworks (logros, nube, multijugador).
- Juegos con anti-cheat a nivel de kernel (Valorant, Fortnite, Call of Duty, Apex Legends, etc.) **no van a funcionar** y algunos hasta pueden banear tu cuenta si lo intentas — esto no es específico de este proyecto, es una limitación de cualquier entorno no-Windows.

## ¿Cómo se actualiza?

El launcher (`Play Steam.command`) se revisa y actualiza solo cada vez que lo abres, si hay una versión más nueva en este repo. No necesitas reinstalar nada manualmente para recibir mejoras al launcher.

## Créditos

Construido sobre [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) (motor Wine para macOS, sucesor de Wineskin/Kegworks) y [Cloudflare WARP](https://1.1.1.1/).
