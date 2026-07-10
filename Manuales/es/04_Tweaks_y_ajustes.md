# 04 · Tweaks y ajustes

## Qué es
**86 ajustes de Windows** (privacidad, rendimiento, interfaz, red, gaming, sistema) aplicables y **reversibles uno a uno**. Cada tweak tiene su interruptor, su color de estado y su detector de estado real: Winzard comprueba en tu Windows si el ajuste está aplicado de verdad, no lo supone.

## El código de colores (leyenda al pie de la lista)
- **Verde + interruptor encendido** = ya aplicado en este PC (detectado de verdad).
- **Ámbar** = tweak avanzado sin aplicar (aplícalo con criterio; su tooltip lo explica).
- **Gris** = acción puntual sin estado (por ejemplo, una limpieza).
- **Color normal** = tweak seguro sin aplicar.

El interruptor es también tu **selección**: enciende los que quieras aplicar, apaga los que no. "APLICAR" omite con aviso lo que ya está aplicado, así que nunca re-ejecuta nada por error.

## Botón a botón
| Botón | Qué hace |
|---|---|
| **Buscador** | Filtra los 86 tweaks en vivo. |
| **Presets Seguro / Equilibrado / Agresivo** | Marca conjuntos con distinto nivel de impacto (nada se aplica hasta que pulses APLICAR). |
| **APLICAR SELECCIONADOS (n)** | Ejecuta solo lo marcado que falte por aplicar. Cada tweak informa de su resultado. |
| **REVERTIR SELECCIONADOS** | Ejecuta el "deshacer" oficial de cada tweak marcado y lo devuelve a su valor por defecto. |
| **Re-detectar estado** | Vuelve a leer el estado REAL de cada tweak en tu Windows y actualiza colores e interruptores. |
| **Verificar todo** | Genera un informe HTML con la verificación de cada ajuste, detector a detector. |
| **Marcar lo recomendado que falta** | Marca los tweaks seguros recomendados que aún no estén aplicados. |
| **Aplicar recomendado para MI equipo** | Analiza tu hardware (portátil/sobremesa, GPU, disco…) y aplica solo lo seguro para TU caso concreto. |
| **Exportar catálogo** | Guarda en `logs\` la lista completa de tweaks (Markdown + JSON) con lo que hace cada uno. |

## Paso a paso típico
1. Pulsa **Re-detectar estado** para ver la foto real de tu PC.
2. Pulsa **Marcar lo recomendado que falta** (o elige un preset, o marca a mano).
3. Revisa lo ámbar: su tooltip y su desplegable ℹ explican qué hace y cuándo evitarlo.
4. Pulsa **APLICAR SELECCIONADOS** y lee el resumen.
5. ¿Algo no te convence? Márcalo y pulsa **REVERTIR SELECCIONADOS**: vuelve al valor por defecto de Windows.

## Ejemplos prácticos
- **"Quiero más privacidad sin riesgo"**: Re-detectar estado → **Marcar lo recomendado que falta** → APLICAR. En un minuto tienes la telemetría, la publicidad y los sugeridos fuera, todo reversible.
- **"Es el PC de mi madre y no quiero líos"**: pulsa **Aplicar recomendado para MI equipo** y ya está — Winzard analiza si es portátil o sobremesa, qué GPU y qué disco tiene, y aplica solo lo seguro para ese hardware.
- **"Aplicué algo y ahora el menú contextual no me gusta"**: busca "menú" en el buscador, enciende ese tweak y pulsa **REVERTIR SELECCIONADOS** — vuelve exactamente al valor de fábrica de Windows.
- **"¿Esto está aplicado de verdad?"**: pulsa **Verificar todo** y abre el informe HTML: cada ajuste con su detector, su valor esperado y su valor real, en verde o rojo.
- **"Quiero la lista entera para leerla con calma"**: **Exportar catálogo** te deja en `logs\` un Markdown y un JSON con los 86 tweaks y su explicación.

## Reversibilidad y seguridad
- Casi todos los tweaks tienen reversión oficial 1:1 (el propio botón REVERTIR). Los pocos que no (una limpieza de temporales, un punto de restauración) lo dicen claramente.
- Todo queda anotado en el **diario de cambios** y el "Paquete de rescate" (Entorno de recuperación) guarda tu perfil de tweaks con el estado real.
- Consejo: crea un punto de restauración antes de una tanda grande (el primer tweak de la lista lo hace por ti).
