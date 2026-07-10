# 12 · Clonar equipo / Snapshot

## Qué es
El **clonado lógico** de tu equipo en un archivo: exporta la lista COMPLETA de programas que winget reconoce en tu PC, en el **formato oficial de `winget import`** (compatible con cualquier herramienta estándar). Ideal para dejar dos máquinas iguales o recuperar tu software tras formatear, sin ir programa por programa.

## Botón a botón
| Botón | Qué hace |
|---|---|
| **Exportar TODO mi equipo a un archivo…** | Genera el archivo de exportación con todos tus programas reconocidos por winget. |
| **Importar un archivo e instalar todo…** | Lee un archivo de exportación y el motor de Winzard instala cada programa de una tacada, con paralelismo, reintentos automáticos y log forense. |
| **Crear catalogo.json editable** | Crea una plantilla del catálogo de apps para que lo personalices (añadir/quitar apps del catálogo de Winzard). |
| **Recargar catalogo.json** | Recarga tu catálogo personalizado (reinicia la app). |
| **Cargar catálogo remoto (URL https)** | Carga un catálogo publicado en una URL (por ejemplo, el de tu equipo o comunidad). |

## Paso a paso: mudanza a un PC nuevo
1. En el PC viejo: **Exportar TODO mi equipo** → guarda el archivo en un USB o nube.
2. En el PC nuevo: instala Winzard, pulsa **Importar un archivo e instalar todo** y elige el archivo.
3. Sigue el progreso en el registro en vivo; los fallos se reintentan al final y se reportan honestos.

## Más ejemplos prácticos
- **"Montamos 5 PCs iguales en la oficina"**: configura uno a mano, **Exportar TODO**, y en los otros cuatro **Importar e instalar todo**. Cafés mientras winget trabaja.
- **"Quiero mi propio catálogo para la familia"**: **Crear catalogo.json editable**, deja solo las apps que quieres que vean, publícalo en tu Drive/web y en cada casa **Cargar catálogo remoto (URL https)**.
- **"¿Y si el archivo lo generó otro programa?"**: mientras sea el formato estándar de `winget export`, Winzard lo importa igual (y viceversa: el suyo vale en cualquier herramienta estándar).

## Notas
- El archivo es JSON estándar de winget: también sirve con `winget import -i archivo.json` a mano.
- El "Paquete de rescate" (Entorno de recuperación) incluye esta exportación automáticamente.
