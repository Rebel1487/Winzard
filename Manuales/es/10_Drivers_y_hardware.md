# 10 · Drivers y hardware

## Qué es
La sección para tener los **drivers al día y con copia de seguridad**, con detección de tu GPU y recomendaciones según tu hardware.

## Botón a botón
| Elemento | Qué hace |
|---|---|
| **GPU detectada + su app oficial** | Detecta tu tarjeta gráfica y te ofrece el botón correcto: **NVIDIA App** (web oficial), **AMD Software: Adrenalin** (web oficial; AMD no distribuye por winget) o **Intel Driver & Support Assistant** (winget). |
| **Abrir web oficial de drivers** | Va a la página de descargas del fabricante detectado. |
| **Otros fabricantes** | Botones siempre disponibles para NVIDIA / AMD / Intel aunque la GPU no se identifique. |
| **Exportar drivers de este PC** | Copia todos los drivers instalados (.inf con sus carpetas) a la carpeta que elijas: tu red de seguridad antes de formatear y la materia prima para inyectarlos en una ISO. |
| **Recomendaciones por hardware** | Marca en el catálogo apps recomendadas según tu equipo (p. ej. utilidades del fabricante). |

## Relación con "Crear ISO"
La carpeta oficial **`Drivers`** del directorio de Winzard es la que el asistente de ISO usa para **inyectar drivers** en la imagen: exporta aquí los de tu PC y tu Windows recién instalado arrancará con red y chipset listos.

## Ejemplos prácticos
- **"Voy a formatear este fin de semana"**: **Exportar drivers de este PC** a un USB. Tras formatear, Windows tendrá red y chipset sin buscar nada — y si creas tu ISO con Winzard, inyéctalos y ni eso.
- **"No sé qué gráfica tengo"**: la sección te la detecta y te pone el botón EXACTO de su software oficial (NVIDIA App / Adrenalin / Intel DSA). Sin webs falsas de "driver boosters".
- **"El portátil de mi trabajo va raro tras un driver"**: descarga siempre del botón de la web oficial del fabricante; nada de terceros.

## Seguridad
- Descargar/instalar drivers siempre pasa por las webs o instaladores **oficiales** del fabricante.
- La exportación no cambia nada: solo copia.
