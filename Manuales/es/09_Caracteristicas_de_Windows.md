# 09 · Características de Windows

## Qué es
El gestor de las **características opcionales** de Windows (Hyper-V, Subsistema de Linux, .NET 3.5, Sandbox, SMB…), con el estado real de cada una detectado en tu equipo.

## Cómo funciona
- Cada característica muestra su estado actual (habilitada / deshabilitada) leído de verdad con DISM.
- Botones **Habilitar** y **Deshabilitar** por característica: son **acciones puntuales con confirmación y verificación** (por diseño, esta sección usa botones y no interruptores: cada cambio puede requerir reinicio y conviene confirmarlo de uno en uno).
- Tras cada acción, el panel **re-escanea** y te enseña el estado real resultante.

## Paso a paso típico
1. Localiza la característica (o llega desde "Buscar en todo").
2. Pulsa **Habilitar** o **Deshabilitar** y confirma.
3. Si Windows pide reinicio, el panel te lo dirá con claridad.

## Ejemplos prácticos
- **"Quiero probar Linux sin salir de Windows"**: habilita **Subsistema de Windows para Linux (WSL)** → reinicia si te lo pide → instala una distro desde la Store.
- **"Necesito una máquina virtual rápida"**: habilita **Hyper-V** (requiere Windows Pro) o **Windows Sandbox** para probar programas sin ensuciar tu equipo.
- **"Un programa antiguo pide .NET 3.5"**: habilítalo aquí y listo — sin buscar instaladores raros por internet.
- **"¿Qué tengo activado realmente?"**: entra y mira: el estado de cada característica está leído de tu Windows con DISM, no supuesto.

## Seguridad
- No hay cambios en lote: cada característica se toca individualmente y verificada.
- Deshabilitar una característica no borra datos: se puede volver a habilitar cuando quieras.
