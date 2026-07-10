# 06 · Control de Windows Update

## Qué es
El centro de control de las actualizaciones: **tú decides cómo y cuándo se actualiza Windows**, mediante políticas reales del sistema. Cada acción se ejecuta al pulsar su botón, se verifica y queda anotada en el log forense. Nada es permanente: el botón de valores por defecto lo revierte todo. Requiere permisos de administrador.

## Las tarjetas (cada una con su botón "Aplicar")
| Acción | Qué hace | Riesgo |
|---|---|---|
| **Configuración recomendada (retrasar updates)** | Difiere las actualizaciones un margen prudente: recibes los parches con unos días de reposo, evitando estrenar fallos de Microsoft. | Seguro |
| **Pausar todas las actualizaciones 5 semanas** | Pausa completa temporal (el máximo que permite Windows por política). | Seguro |
| **Valores por defecto de Windows Update** | Borra cualquier política aplicada desde esta lista y devuelve Windows Update a su comportamiento de fábrica. | Seguro |
| **Desactivar Windows Update por completo** | Apaga el servicio y sus políticas. Pide confirmación con un aviso claro: dejar Windows sin parches de seguridad es arriesgado; úsalo solo si sabes lo que haces (equipos de laboratorio, VMs de prueba…). | Avanzado (borde rojo) |

## Enlaces rápidos
Botones que abren directamente las páginas relevantes de Configuración de Windows Update.

## Paso a paso típico
1. Pulsa **Aplicar** en "Configuración recomendada": es el punto dulce para la mayoría.
2. ¿Vas a jugar un fin de semana de lanzamiento o a un viaje? "Pausar 5 semanas".
3. ¿Quieres volver a como estaba todo? **Valores por defecto** y listo.

## Ejemplos prácticos
- **"Windows me actualizó a mitad de partida"**: aplica **Configuración recomendada** — los parches llegan igual, pero con unos días de reposo y sin pillarte por sorpresa.
- **"Me voy de viaje con el portátil y no quiero sustos"**: **Pausar 5 semanas** antes de salir; al volver, **Valores por defecto** y Windows se pone al día.
- **"Toqué algo hace meses y ahora no sé qué tengo"**: pulsa **Valores por defecto de Windows Update** — borra CUALQUIER política de esta lista y deja Windows Update de fábrica, sin que tengas que recordar qué aplicaste.
- **"Es una VM de pruebas y no quiero que se actualice nunca"**: **Desactivar por completo** (confirma el aviso rojo). Solo para equipos que de verdad no necesitan parches.

## Reversibilidad
Todas las acciones de esta sección se revierten con "Valores por defecto de Windows Update". Todo queda registrado en `logs\`.
