# 05 · Gaming Optimizer

## Qué es
La preparación **honesta** del PC para jugar. Aquí no hay promesas de FPS: se trabaja con estabilidad, latencia, frametimes y microtirones, con todo reversible y verificado. Se organiza en 4 subsecciones (píldoras): **Preparar · Jugar · Automatizar · Medir**, más un botón de un clic arriba.

## Arriba del todo
| Elemento | Qué hace |
|---|---|
| **Optimizar para jugar (modo fácil)** | Un clic seguro: refresca el chequeo, revisa el Game Mode de Windows y delega ProBalance en Process Lasso si está instalado. |
| **Ver plan (sin tocar nada)** | Muestra EXACTAMENTE qué haría la activación (o la restauración) del Modo Juego: plan de energía y procesos con sus PID. No cambia nada. |

## PREPARAR
- **Chequeo previo (solo lectura):** GPU, CPU, RAM, disco, HAGS y VRR, estado de los tweaks gaming del catálogo (verde = aplicado). Analiza y recomienda; no cambia nada.
- **Radar de overlays:** detecta Game Bar, Discord, NVIDIA Overlay, OBS, RivaTuner y el overlay de Steam (puntos verde/ámbar); el tooltip te dice dónde se apaga cada uno. Winzard no los toca.
- **Red para online → "Medir red (10 s)":** 10 pings reales a 1.1.1.1 en segundo plano; te da media, mínimo, máximo, jitter y pérdida, con veredicto honesto. La interfaz no se congela.

## JUGAR
- **Modo Juego por sesión (100 % reversible):** al activarlo cambia el plan de energía al máximo y PAUSA (nunca cierra) los procesos de TU lista; al desactivarlo, todo vuelve exactamente como estaba.
  - **Lista de pausa:** tú eliges los procesos; nada viene marcado de fábrica; los procesos críticos del sistema están protegidos y no se pueden pausar.
  - **Silenciar notificaciones durante la sesión:** interruptor opcional; guarda tu valor previo exacto y lo restaura al salir.
  - Si la app se cerrara a mitad de sesión, al reabrirla detecta la sesión pendiente y ofrece **"Restaurar todo"**.
- **Motor en tiempo real (delegado):** el trabajo en tiempo real (ProBalance, prioridades) se delega en **Process Lasso**; Winzard no incluye un planificador propio a propósito.
- **Presets:** *Competitivo* (plan máximo + ProBalance + tu lista de pausa) y *Equilibrado* (solo ProBalance). Solo marcan opciones: nada se ejecuta hasta que actives la sesión.

## AUTOMATIZAR
- **Detección automática de juego (apagada por defecto):** con el interruptor maestro encendido, vigila tus juegos asociados (comprobación ligera cada 5 s) y activa/revierte el Modo Juego solo.
- **Juegos instalados detectados:** escanea Steam, Epic, GOG, Ubisoft, Xbox/Game Pass, Riot, EA, Battle.net y cualquier juego ya ejecutado (registro de Windows). Botón **Asociar** de un clic por juego.
- **Launchers detectados:** sus procesos de fondo son candidatos a la lista de pausa; nada viene marcado.

## MEDIR
- **Medición honesta:** con la edición de CONSOLA de PresentMon captura 60 s de frametimes a `logs\frametimes_<fecha>.csv` y te da media, p95 y p99. Si falta el binario, te lo dice claro y te lleva a las descargas oficiales.
- Botones para instalar **PresentMon / CapFrameX** vía winget (medición externa de confianza).

## Ejemplos prácticos
- **"Voy a jugar YA y no quiero configurar nada"**: pulsa **Optimizar para jugar (modo fácil)** — chequeo fresco, Game Mode revisado y ProBalance delegado si tienes Process Lasso. Un clic y a jugar.
- **"Quiero que el modo juego se active SOLO cuando abro mi shooter"**: en AUTOMATIZAR pulsa **Asociar** junto a tu juego detectado, elige el preset *Competitivo*, enciende el interruptor maestro… y olvídate: al abrir el juego se activa la sesión y al cerrarlo todo vuelve solo.
- **"Me va a tirones y no sé si es la red"**: en PREPARAR pulsa **Medir red (10 s)** — si el jitter y la pérdida salen bien, el problema no es tu conexión; pasa a MEDIR y captura 60 s de frametimes con PresentMon para ver los microtirones en datos reales (media, p95, p99).
- **"¿Qué me va a tocar exactamente si activo la sesión?"**: pulsa **Ver plan (sin tocar nada)**: te lista el plan de energía y cada proceso con su PID que se pausaría. Transparencia total antes de decidir.
- **"Se me fue la luz a mitad de sesión"**: reabre Winzard — detecta la sesión pendiente y te ofrece **Restaurar todo** para dejar el plan de energía y los procesos exactamente como estaban.

## Reglas de esta sección (por diseño)
Sin promesas de FPS · sin "liberadores de RAM" · sin planificador propio · sin afinidad automatizada de CPU · pausar significa suspender con el mecanismo nativo de Windows y reanudar SIEMPRE · todo reversible y anotado en el diario.
