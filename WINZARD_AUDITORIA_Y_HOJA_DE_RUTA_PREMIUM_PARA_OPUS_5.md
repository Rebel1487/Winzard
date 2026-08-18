# WINZARD — Auditoría técnica completa y hoja de ruta premium de referencia

> **Documento de contexto para Opus 5 y para la planificación técnica de WINZARD**  
> **Proyecto auditado:** WINZARD  
> **Commit auditado:** `cdcb25ab114d34dbc1f98295b4109fcbcd1d3be9`  
> **Tipo de revisión:** auditoría estática y estrictamente de solo lectura  
> **Fecha de referencia:** 18 de agosto de 2026  
> **Estado del repositorio al auditar:** árbol Git limpio  
> **Archivos de WINZARD modificados durante la auditoría:** ninguno

---

## 0. Propósito de este documento

Este documento reúne dos bloques complementarios:

1. **La auditoría completa ya realizada sobre WINZARD**, conservada con sus hallazgos, evidencias, limitaciones y veredicto.
2. **Una hoja de ruta técnica premium de referencia**, donde se explica qué arreglos y mejoras consideraría razonables, en qué zonas del proyecto investigaría, cómo podrían resolverse, qué elementos podrían simplificarse o retirarse y cómo podría validarse cada cambio.

La segunda parte **no pretende ser una lista de órdenes para ejecutar mecánicamente**. Es un conjunto de hipótesis, alternativas y criterios técnicos para que Opus 5:

- investigue cada asunto directamente en el código actual;
- confirme o descarte cada diagnóstico;
- compruebe si las líneas y flujos siguen vigentes;
- valore compatibilidad, impacto, coste y riesgo;
- proponga un planning realista basado en dependencias;
- distinga correcciones necesarias de mejoras opcionales;
- no cambie nada destructivo o de alto impacto sin aprobación del propietario;
- preserve las funciones útiles de WINZARD en vez de reescribir por reescribir.

### Cómo debería interpretarlo Opus 5

Este documento aporta contexto y una dirección técnica, pero Opus 5 debería tratarlo como **material de investigación**, no como verdad inmutable. Antes de convertir una idea en tarea de implementación convendría que:

1. Localice de nuevo la implementación real.
2. Reconstruya el flujo completo de entrada, validación, elevación, ejecución, registro, recuperación y salida.
3. Determine si el hallazgo es reproducible, condicional o ya fue corregido.
4. Identifique todos los consumidores y dependencias del código afectado.
5. Proponga una corrección mínima segura y, cuando proceda, una mejora estructural posterior.
6. Defina pruebas y criterios de aceptación antes de tocar el código.
7. Reserve las pruebas de DISM, drivers, tareas, reparación, ISO y borrado para una VM aislada con snapshots.
8. Presente al propietario un planning priorizado antes de implementar cambios amplios.

---

# PARTE I — INFORME FINAL DE AUDITORÍA

## 1. Veredicto ejecutivo

**WINZARD es un proyecto ambicioso, amplio y con bastante trabajo real detrás**, especialmente en interfaz, automatización, soporte bilingüe, reparación, administración de aplicaciones, generación ISO y documentación.

Sin embargo, mi veredicto honesto es:

> **No considero que la versión auditada esté preparada para recomendarse como herramienta de mantenimiento desatendido o de uso general en equipos reales sin supervisión técnica.**

La razón no es un único error, sino la combinación de:

- Operaciones ejecutadas con privilegios elevados.
- Argumentos inválidos que pueden activar acciones reales.
- Modos llamados `dry`, `selftest` o «solo escaneo» que producen efectos laterales.
- Estados y códigos de salida que pueden informar éxito cuando hubo fallos.
- Construcción y validación ISO con controles insuficientes.
- Riesgos de inyección o sustitución de scripts elevados.
- Actualización remota sin verificación criptográfica.
- Operaciones potencialmente destructivas y reversibilidad parcial.
- Diferencias importantes entre documentación y comportamiento real.

**Calificación orientativa del estado auditado:**

| Área | Valoración orientativa |
|---|---:|
| Amplitud funcional | 8/10 |
| Diseño visual y documentación | 7/10 |
| Fiabilidad del resultado comunicado | 5/10 |
| Seguridad de operaciones elevadas | 4/10 |
| Seguridad para automatización desatendida | 3/10 |
| Preparación general para producción | 5/10 |

Lo clasificaría como **beta avanzada apta para laboratorio y usuarios expertos**, pero no como versión estable para distribución masiva hasta corregir los puntos prioritarios.

---

## 2. Alcance cubierto

La auditoría fue estrictamente de solo lectura. Se revisaron:

- `WPI_Moderno.ps1`, de aproximadamente 18.900 líneas.
- `Iniciar_WPI.bat`.
- Parámetros CLI, GUI WPF y rutas de autoelevación.
- Catálogos, perfiles, winget, actualizaciones y debloat.
- Tweaks, journaling y restauración.
- Diagnóstico, drivers y hardware.
- Recuperación y tareas programadas.
- Constructor y verificador ISO.
- Suites de reparación ES/EN y sus 17 fases.
- Fuentes canónicas de generación:
  - `header.cmd`
  - `orquestador.body.cmd`
  - `lib_wpi.cmd`
  - `suite_helper.ps1`
  - `manifest.psd1`
- Scripts generadores y comprobadores.
- Configuración, idiomas, manuales ES/EN, README, changelog e informes.
- CI de GitHub Actions y cadena de suministro.
- Privilegios, datos recogidos, conexiones de red y operaciones destructivas.

No se modificó ningún archivo ni se ejecutaron reparaciones, DISM, winget, generación ISO, montaje de imágenes o llamadas de red.

---

# 3. Hallazgos críticos operativos

## C-01. El modo ISO «VM» puede borrar por completo el disco 0

El archivo desatendido generado utiliza:

- `DiskID 0`
- `<WillWipeDisk>true>`

Esto es coherente con una instalación automatizada en una VM desechable, pero es **catastrófico si el medio se inicia accidentalmente sobre un equipo físico**.

No lo considero una vulnerabilidad por sí mismo, pero sí el mayor peligro operativo encontrado.

Medidas que deberían estudiarse:

- Advertencia explícita e imposible de ignorar.
- Nombre del modo que indique claramente «BORRA DISCO 0».
- Confirmación reforzada.
- Separación entre plantillas para VM y hardware real.
- Documentación visible dentro y fuera de la aplicación.
- Preferiblemente, validación adicional durante el arranque.

## C-02. Credenciales desatendidas almacenadas en texto plano

La contraseña configurada para instalaciones desatendidas puede quedar en:

- `kit-config.json`
- `autounattend.xml`

Cualquier persona que obtenga la carpeta o ISO puede recuperarla. La documentación no advierte con suficiente claridad de esta exposición.

Debe considerarse que una contraseña incluida en una ISO **ya no es secreta**.

---

# 4. Hallazgos de severidad alta

## A-01. Argumentos desconocidos se ignoran

En:

- `Suite_Reparacion_ES/src/header.cmd:25-57`
- `Suite_Reparacion_EN/src/header.cmd:25-57`

Los parámetros desconocidos no producen un error fatal.

Ejemplo:

```cmd
Suite_Reparacion.bat /auto /drry
```

El error tipográfico `/drry` puede ignorarse y `/auto` continuar, provocando una reparación real cuando el usuario creía haber solicitado un simulacro.

**Corrección requerida:** lista cerrada de argumentos, error inmediato y código de salida distinto de cero ante cualquier parámetro desconocido.

## A-02. `/dry` y `/selftest` no son estrictamente inocuos

Las rutas de simulación y autoprueba pueden:

- Crear carpetas.
- Generar estado, informes y logs.
- Escribir temporales.
- Tocar potencialmente `HKCU\Console`.

Evidencia principal:

- `header.cmd:62-98`
- `lib_wpi.cmd:6-25`
- `orquestador.body.cmd:25-40`
- `orquestador.body.cmd:292-304`
- `orquestador.body.cmd:383-405`

Por tanto, las afirmaciones documentales de «no cambia nada» no son correctas.

## A-03. Inicialización de winget antes de las protecciones de modo seguro

En `WPI_Moderno.ps1:5046-5049`, opciones como:

- `-DryRun`
- `-SelfTestGui`
- `-BuildIsoKit`

pueden atravesar primero la resolución o instalación de winget y la actualización de fuentes.

Esto puede producir:

- Cambios en el sistema.
- Acceso a red.
- Instalación de componentes.
- Actualización de catálogos.

La guarda del modo seguro debe ejecutarse antes de cualquier inicialización con efectos laterales.

## A-04. Posible inyección elevada mediante `/source:`

En `suite_helper.ps1:1435-1495`, el origen proporcionado por el usuario acaba participando en la construcción de una orden para `cmd.exe /c dism.exe`.

La concatenación a través de `cmd.exe` crea una superficie probable de metacaracteres e inyección, especialmente peligrosa porque la suite se ejecuta elevada.

**Confianza:** alta por revisión estática.  
**Explotación confirmada:** no; requeriría una prueba controlada en VM.

La solución correcta es evitar `cmd.exe /c`, invocar directamente el ejecutable y pasar los argumentos como una colección correctamente tipada y validada.

## A-05. `_oscdimg.cmd` se genera desde configuración editable

En `WPI_Moderno.ps1:14055-14090`, se construye un archivo CMD utilizando datos procedentes de `kit-config.json`.

Esto combina:

- Datos editables.
- Generación de comandos.
- Ejecución de una herramienta externa.
- Posibles privilegios elevados.

Debería estudiarse la eliminación de la capa CMD y la ejecución directa de `oscdimg.exe`, validando y separando cada argumento.

## A-06. Riesgo TOCTOU/reparse en helper elevado

La suite genera o usa helpers dentro de `%SELFDIR%WPI_Suite` y emplea identificadores basados en `%RANDOM%`.

Entre la creación, comprobación y ejecución elevada pueden existir oportunidades para:

- Sustitución del archivo.
- Junctions o enlaces de reprocesamiento.
- Colisiones.
- Cambio del contenido después de la validación.

No se confirmó explotación porque requiere estudiar ACL y carreras temporales en una VM, pero el patrón no es adecuado para una frontera de elevación.

## A-07. Tareas programadas elevadas dependen de scripts externos

Se identificaron tareas como:

- `WPI_ReintentoManual`
- `WPI_ReintentoApps`
- `WPI_Mantenimiento_Mensual`

Estas pueden ejecutar scripts con nivel `Highest` o `SYSTEM`.

Si un usuario no privilegiado pudiera modificar el script, su directorio o redirigirlo mediante un reparse point, existiría una vía de escalada.

**Riesgo condicionado a las ACL reales del sistema.** Debería validarse siempre:

- Propietario.
- DACL.
- Herencia.
- Ausencia de enlaces o junctions.
- Hash o firma del script antes de ejecutarlo.

## A-08. Autoactualización sin verificación de integridad

`Invoke-SelfUpdate` descarga, sobrescribe y vuelve a ejecutar contenido sin exigir:

- Hash conocido.
- Firma Authenticode.
- Host permitido.
- HTTPS obligatorio.
- Versión o manifiesto firmado.

La URL por defecto puede estar vacía, pero si esta función se configura, el modelo de confianza es insuficiente para código que posteriormente se ejecutará con privilegios.

## A-09. Script temporal fijo para exportar drivers

Se utiliza una ruta predecible semejante a:

```text
%TEMP%\wpi_drv_export.ps1
```

Posteriormente puede relanzarse elevada. Un nombre fijo en un directorio compartido o controlable crea riesgo de sustitución y carrera.

Debería usarse un directorio temporal exclusivo creado de manera segura, con ACL restrictiva y limpieza garantizada.

## A-10. Valores desconocidos de `-Update` activan actualización global

En `WPI_Moderno.ps1:4850-4880`, un valor desconocido puede caer en:

```text
winget upgrade --all
```

Un error tipográfico no debe transformarse en la operación más amplia disponible.

Debe rechazarse cualquier valor que no pertenezca a una enumeración cerrada.

## A-11. El CLI puede finalizar con `exit 0` a pesar de fallos

En `WPI_Moderno.ps1:5407`, la salida general puede ser cero aunque alguna operación interna haya fallado.

Esto invalida su uso fiable desde:

- CI.
- Scripts.
- Automatizaciones.
- Sistemas de monitorización.
- Tareas programadas.

Los fallos parciales deben agregarse y reflejarse en el código final.

## A-12. La suite convierte resultados inesperados en `OK`

En:

- `Suite_Reparacion_ES/src/orquestador.body.cmd:230-252`
- `Suite_Reparacion_EN/src/orquestador.body.cmd:223-245`

Un código de retorno inesperado puede quedar registrado como `OK`. Además, una fase intentada entra en `COMPLETED` aunque no haya terminado correctamente.

Esto es especialmente grave porque produce **falsa confianza** después de acciones de mantenimiento potencialmente destructivas.

## A-13. Verificador ISO acepta ausencia de `autounattend.xml`

En `Verificar_ISO.ps1:60-68` y `107-115`, la ausencia de `autounattend.xml` no incrementa adecuadamente `$fatal` ni garantiza `exit 1`.

Una ISO incompleta puede presentarse como válida.

## A-14. El constructor ISO ignora resultados de `robocopy`

En `WPI_Moderno.ps1:13719-13721`, `13958-13970` y `14053-14069`, no se interpretan correctamente los códigos de `robocopy`.

`robocopy` utiliza códigos especiales; no basta con tratarlos como un booleano convencional. Los resultados superiores al rango aceptable deben detener la construcción.

En el estado auditado podría generarse una ISO sin el payload completo de WPI.

## A-15. Integración de drivers con `-ForceUnsigned`

Aceptar controladores no firmados aumenta considerablemente el riesgo de:

- Imágenes que no arrancan.
- Drivers manipulados.
- Inestabilidad.
- Incompatibilidad con Secure Boot o políticas modernas.

Debería ser una opción avanzada, desactivada por defecto y acompañada de una advertencia fuerte.

---

# 5. Hallazgos de severidad media

## M-01. «Inspección rápida: solo escaneo» realiza cambios

Esta ruta puede:

- Ejecutar `ipconfig /flushdns`.
- Crear informes y estado.
- Iniciar servicios necesarios para consultas.

No es solamente una lectura del sistema. Debería cambiarse el nombre o eliminarse esas operaciones del modo de inspección.

## M-02. El journal de tweaks se escribe antes de saber si funcionaron

En `WPI_Moderno.ps1:12139-12140`, `18571-18572` y `18586`, el journal puede registrar una modificación antes de confirmar su éxito.

Esto puede hacer que la reversión intente deshacer algo que nunca llegó a aplicarse.

## M-03. «Undo» no restaura necesariamente el estado original

Varias reversiones aplican valores predeterminados codificados en lugar de restaurar el valor previo del usuario.

Por tanto, «reversible» significa en muchos casos «volver a una configuración elegida por WINZARD», no «volver exactamente al estado anterior».

## M-04. Acciones manuales anuncian éxito sin validar el código de retorno

Existen rutas donde se muestra `OK` después de lanzar una orden sin comprobar adecuadamente su resultado.

Toda acción visible debería terminar en uno de estos estados:

- Completada.
- Completada con advertencias.
- Omitida.
- Fallida.

## M-05. Política de puntos de restauración no protegida con `finally`

En `suite_helper.ps1:230-240`, la política `SystemRestorePointCreationFrequency` puede modificarse temporalmente sin que su restauración esté garantizada ante una excepción.

## M-06. Diagnóstico de RAM puede informar éxito sin datos suficientes

Consultas vacías o no disponibles pueden acabar interpretadas como estado correcto. «No se pudo consultar» debe distinguirse de «sin errores».

## M-07. SMART solo inspecciona el primer disco

El uso de:

```powershell
Get-PhysicalDisk | Select-Object -First 1
```

no representa correctamente sistemas con varios discos.

## M-08. SFC puede mezclar información histórica

La lectura de CBS puede incluir eventos anteriores y atribuirlos a la ejecución actual. Debería delimitarse por tiempo o capturarse el estado previo.

## M-09. El ZIP de soporte inglés puede omitir el informe HTML

En `Suite_Reparacion_EN/src/suite_helper.ps1:1374-1377`, se busca un patrón similar a `^Informe`, mientras el archivo inglés utiliza `Report_<timestamp>.html`.

## M-10. Falsos positivos en actualización de fuentes y debloat

En `WPI_Moderno.ps1:3957-3961` y `4990-5015`, ciertas operaciones pueden anunciar éxito sin confirmar que winget o la eliminación hayan finalizado correctamente.

## M-11. Limpieza ISO no transaccional

El constructor y verificador no están protegidos por un `try/finally` global que garantice:

- Desmontaje.
- Eliminación de temporales.
- Restauración de estado.
- Liberación de archivos.
- Limpieza después de una excepción.

Además, el uso de una ruta fija como `C:\_wpichk` facilita colisiones y problemas de ejecución simultánea.

## M-12. Paquete de soporte con información sensible

El paquete puede incluir:

- Nombre del equipo.
- Usuario.
- Hardware.
- Procesos.
- Red.
- Comandos de inicio.
- Estado de servicios y software.

No se observó carga automática de ese paquete a terceros, lo cual es positivo, pero faltan:

- Vista previa.
- Redacción de identificadores.
- Consentimiento explícito.
- Advertencia antes de compartirlo.

## M-13. Cadena de suministro mejorable

Los hashes locales coinciden, pero:

- Hash y artefacto se distribuyen desde el mismo contexto.
- No existe firma del manifiesto.
- No existe firma Authenticode consistente.
- Hay URLs `latest` y `aka.ms`.
- No se fijan versiones o digest de todas las dependencias.

## M-14. CI no fija completamente las acciones

`.github/workflows/verify.yml` utiliza `actions/checkout@v4`, que es una referencia mutable, y no declara explícitamente:

```yaml
permissions:
  contents: read
```

Para una cadena de suministro más robusta, las acciones deberían fijarse por SHA.

## M-15. El `-Check` del generador no prueba una reconstrucción completa

`build/generar.ps1 -Check` compara algunos elementos y el BAT generado, pero no sustituye una reconstrucción limpia y una comparación reproducible de todos los artefactos.

---

# 6. Problemas documentales y de UX

## D-01. `-Profile` frente a `-ProfilePath`

Los manuales utilizan `-Profile`, mientras el código declara `-ProfilePath` en `WPI_Moderno.ps1:382-402`.

PowerShell puede aceptar actualmente la abreviación inequívoca, pero no es una interfaz contractual estable. Si se añade otro parámetro con el mismo prefijo, podría dejar de funcionar.

## D-02. Descripción incorrecta del debloat

La documentación presenta los componentes como Appx reinstalables, pero:

- OneDrive no es simplemente un paquete Appx.
- `Microsoft.Xbox.TCUI` contiene una excepción que no encaja con la promesa general de reversibilidad.

## D-03. Faltan advertencias sobre contraseñas en ISO

Debería explicarse prominentemente que `autounattend.xml` y la configuración del kit pueden contener credenciales recuperables.

## D-04. Catálogo remoto sin modelo de confianza documentado

HTTPS protege el transporte, pero no sustituye:

- Firma.
- Hash esperado.
- Control de versión.
- Autor permitido.
- Validación de esquema y comandos.

## D-05. Afirmaciones absolutas incorrectas

No están justificadas expresiones como:

- «Todo reversible».
- «No cambia nada».
- «100 % desatendida».
- «Winget nunca caduca».
- «Solo usa red para descargar aplicaciones».

La aplicación también puede utilizar red para actualización propia, fuentes, GitHub, `aka.ms`, certificados, DNS, ping y Windows Update.

## D-06. Autoelevación documentada de forma obsoleta

El manual 15 no refleja exactamente el comportamiento actual de elevación.

## D-07. `guias.json` se documenta pero no existe

La documentación presenta un archivo o mecanismo que no está presente ni cargado por la aplicación.

## D-08. Idioma español forzado

`wpi_settings.json` contiene:

```json
"Lang": "es"
```

Eso puede anular la autodetección y hacer que un primer arranque en Windows inglés aparezca en español.

## D-09. Ayuda incompleta de las suites

La ayuda no enumera correctamente opciones disponibles como:

- `/quickfix`
- `/manual`
- `/cmd`
- `/plan`
- `/resetbase`
- `/fwreset`
- `/source:`

## D-10. Número de pasos ISO inconsistente

Un manual habla de siete pasos, mientras README, changelog o código describen ocho.

## D-11. Conteos inconsistentes

Aparecen cifras diferentes:

- 350+, 352, 360+ o 362 aplicaciones.
- 40+ frente a 86 tweaks.

Conviene generar estos datos automáticamente desde los catálogos.

## D-12. Versión 3.1 frente a 3.2

La suite reporta 3.1 en lugares donde los cambios o documentos se identifican como 3.2.

## D-13. Enlaces internos rotos

Hay enlaces y anclas de README ES/EN que no llevan a su destino correcto.

---

# 7. Aspectos positivos

También se encontraron fortalezas importantes:

- Cobertura funcional excepcionalmente amplia para un proyecto PowerShell.
- Interfaz WPF trabajada y soporte CLI.
- Manuales extensos en español e inglés.
- Separación de fuentes canónicas para generar las suites.
- Existencia de CI y verificadores internos.
- Uso de manifiestos y hashes locales.
- Registro e informes de operaciones.
- Intentos de crear puntos de restauración y mecanismos de undo.
- Diferenciación conceptual entre modos manuales, automáticos y simulados.
- No se observó un bypass UAC clásico.
- `ExecutionPolicy Bypass` reduce una barrera, pero no equivale a evadir UAC.
- No se observó telemetría ni subida automática de datos.
- La mayoría de los problemas parecen corregibles sin rediseñar completamente el producto.

El problema principal no es falta de funcionalidad, sino que **la capa de seguridad, validación y comunicación de resultados no ha alcanzado todavía el nivel de la amplitud funcional**.

---

# 8. Validaciones y límites

## Validaciones seguras realizadas

- Inspección estática del código y scripts.
- Parseo de PowerShell sin errores sintácticos reportados.
- Revisión de parámetros y rutas de ejecución.
- Contraste entre fuentes canónicas y artefactos.
- Comprobación de hashes locales.
- Revisión de configuración CI.
- Estado Git limpio.
- HEAD auditado:

```text
cdcb25ab114d34dbc1f98295b4109fcbcd1d3be9
```

## Pruebas no ejecutadas

No se ejecutaron:

- `Verificar_Proyecto.ps1`
- `/selftest`
- `/dry`
- Winget.
- DISM/SFC/CHKDSK.
- Reparaciones.
- Debloat o tweaks.
- Tareas programadas.
- Montaje o generación ISO.
- Autoactualización.
- Acceso de red.

Estas rutas no son estrictamente de solo lectura: pueden generar temporales, logs y estado, modificar `HKCU\Console`, actualizar fuentes, arrancar servicios o cambiar Windows.

Por ello, no se deben interpretar como explotación confirmada los riesgos de:

- Inyección por `/source:`.
- Carreras TOCTOU.
- Junctions/reparse points.
- Sustitución de scripts de tareas.
- ACL inseguras.
- Comportamiento real de una ISO arrancada.

Esos casos requieren una VM aislada, snapshots y pruebas deliberadamente destructivas.

---

# 9. Prioridad recomendada originalmente

## P0 — Antes de otra publicación pública

1. Rechazar argumentos y valores desconocidos.
2. Hacer que `dry`, `selftest` y «solo escaneo» sean realmente inocuos.
3. Mover todas las guardas antes de winget, red o inicialización.
4. Eliminar concatenaciones mediante `cmd.exe /c`.
5. Proteger helpers temporales y scripts elevados contra sustitución/reparse.
6. Verificar criptográficamente las autoactualizaciones.
7. Corregir códigos de salida y estados falsamente `OK`.
8. Añadir protección extrema al modo ISO que borra el disco 0.
9. Corregir el control de `robocopy` y la validación de ISO.
10. Advertir y reducir la exposición de contraseñas desatendidas.

## P1 — Antes de considerarlo estable

1. Implementar ejecución transaccional y `try/finally` en ISO.
2. Validar owner, ACL y hash de scripts ejecutados por tareas elevadas.
3. Desactivar `ForceUnsigned` por defecto.
4. Registrar el estado previo real para undo.
5. Diferenciar «sin datos», «fallo» y «correcto» en diagnósticos.
6. Corregir el informe ZIP inglés.
7. Añadir redacción y consentimiento al paquete de soporte.
8. Ampliar CI con pruebas negativas de argumentos y códigos de salida.

## P2 — Calidad y mantenimiento

1. Sincronizar documentación y código desde una fuente única.
2. Corregir versiones, pasos, conteos, enlaces y nombres de parámetros.
3. Dividir progresivamente `WPI_Moderno.ps1` en módulos.
4. Fijar acciones CI y dependencias por SHA o versión verificable.
5. Firmar artefactos, manifiestos y releases.
6. Crear pruebas en VM para cada operación elevada o destructiva.

---

# 10. Conclusión original

WINZARD **no es un proyecto vacío ni superficial**. Tiene una base funcional considerable y podría convertirse en una herramienta muy buena. Pero actualmente maneja demasiadas operaciones críticas bajo elevación como para tolerar parámetros ambiguos, resultados falsamente positivos, temporales predecibles o documentación demasiado optimista.

La recomendación es:

> **No abandonar el proyecto, pero detener la expansión de funcionalidades temporalmente y dedicar la siguiente etapa exclusivamente a seguridad, fiabilidad, códigos de retorno, modos seguros y pruebas en VM.**

Con las correcciones P0 y P1, una batería reproducible de pruebas destructivas en máquinas virtuales y una segunda auditoría, el proyecto podría pasar de **beta avanzada** a una versión estable defendible.

---

# PARTE II — PROPUESTA PREMIUM DE ARREGLOS Y MEJORAS

## 11. Filosofía general que aplicaría

Antes de añadir más botones o utilidades, orientaría WINZARD alrededor de seis principios:

1. **Seguro por defecto:** una entrada inválida nunca debe ampliar el alcance de una operación.
2. **Simulación real:** un modo de lectura no debe modificar registro, servicios, red, temporales persistentes ni configuración.
3. **Resultados honestos:** si una herramienta externa falla, WINZARD no debe anunciar éxito.
4. **Privilegio mínimo:** recopilar y planificar sin elevación; elevar únicamente la unidad de trabajo que lo necesite.
5. **Reversión basada en estado real:** guardar el valor anterior, no asumir un valor predeterminado.
6. **Una fuente de verdad:** catálogos, parámetros, traducciones, ayuda, documentación, versiones y artefactos deberían derivarse de metadatos canónicos.

### Objetivo de producto

WINZARD podría evolucionar de «script enorme que sabe hacer muchas cosas» a una **plataforma local de mantenimiento de Windows con planes explícitos, ejecución controlada, auditoría completa y recuperación verificable**.

La experiencia premium no consistiría en más efectos visuales, sino en que el usuario pueda saber con precisión:

- qué se va a hacer;
- por qué;
- qué requiere elevación;
- qué descargará datos;
- qué puede reiniciar o romper algo;
- cómo se verificará el resultado;
- cómo se puede revertir;
- qué no pudo comprobarse.

---

# 12. Flujo de investigación recomendado para Opus 5

Antes de formar un plan definitivo, propondría que Opus 5 produzca una matriz por hallazgo con estas columnas:

| Campo | Contenido esperado |
|---|---|
| Identificador | C-01, A-01, etc. |
| Evidencia vigente | Archivo, función y líneas actuales |
| Flujo completo | Entrada → validación → elevación → ejecución → resultado |
| Clasificación | Confirmado, probable, condicional o descartado |
| Impacto | Seguridad, pérdida de datos, fiabilidad, UX o mantenimiento |
| Probabilidad | Baja, media o alta |
| Compatibilidad | Qué usuarios, parámetros o artefactos podrían verse afectados |
| Solución mínima | Parche seguro de menor alcance |
| Solución estructural | Diseño objetivo posterior |
| Pruebas | Unitarias, integración, VM, negativas y recuperación |
| Criterio de aceptación | Evidencia concreta de que quedó resuelto |
| Dependencias | Qué debe hacerse antes |
| Decisión | Hacer, aplazar, rediseñar o retirar |

Opus 5 debería contrastar especialmente las rutas generadas con sus fuentes canónicas, para evitar arreglar solamente un BAT producido y perder la corrección al regenerarlo.

---

# 13. Línea de trabajo 1 — Contrato estricto de CLI y argumentos

## Problema que resolvería

- Argumentos desconocidos ignorados.
- Valores desconocidos de `-Update` que terminan en `upgrade --all`.
- Abreviaciones documentadas como `-Profile` sin contrato estable.
- Ayuda incompleta.
- Posibles combinaciones incompatibles sin rechazo temprano.

## Dónde investigaría

- Bloque `param(...)` de `WPI_Moderno.ps1`.
- Despacho CLI aproximadamente en las zonas de las líneas 382-402, 4850-4880 y 5046-5407.
- `Suite_Reparacion_ES/src/header.cmd`.
- `Suite_Reparacion_EN/src/header.cmd`.
- Generador que produce los BAT finales.
- Manuales y ejemplos de comandos.

## Cómo lo plantearía

### Solución mínima

- Declarar conjuntos cerrados mediante `ValidateSet` o enumeraciones.
- Rechazar argumentos desconocidos antes de elevar o inicializar nada.
- Definir combinaciones incompatibles y devolver un error claro.
- Conservar temporalmente alias explícitos si existen usuarios que usan nombres antiguos.
- Hacer que `--help`, `/?` o equivalente se generen desde la misma definición de parámetros.

### Solución premium

Crear un modelo canónico de comando, por ejemplo conceptualmente:

```powershell
[pscustomobject]@{
    Name = 'Update'
    AllowedValues = @('List', 'Selected', 'All')
    RequiresElevation = $true
    HasNetworkEffects = $true
    SupportsDryRun = $true
    DestructiveLevel = 'Medium'
}
```

GUI, CLI, ayuda y documentación podrían consumir esos metadatos. Esto evitaría que una opción exista en código, pero no en ayuda.

## Criterios de aceptación sugeridos

- Cualquier argumento desconocido devuelve un código distinto de cero.
- Ningún error tipográfico ejecuta una operación más amplia.
- `-Update valor-invalido` no llama a winget.
- Las combinaciones incompatibles fallan antes de UAC, red o escritura.
- La ayuda enumera exactamente las opciones disponibles.
- Las pruebas recorren valores válidos, inválidos, vacíos, duplicados y con caracteres especiales.

---

# 14. Línea de trabajo 2 — Modo seguro, dry-run y planificación sin efectos laterales

## Problema que resolvería

Los modos `DryRun`, `selftest` y «solo escaneo» no tienen una frontera clara de efectos. Un usuario no puede confiar plenamente en sus nombres.

## Diseño que preferiría

Separaría el sistema en tres fases:

1. **Discover:** recopilar estado sin cambios.
2. **Plan:** construir una lista de acciones, requisitos, riesgos y reversión.
3. **Apply:** ejecutar únicamente después de confirmación.

Un `DryRun` real recorrería `Discover + Plan`, pero nunca `Apply`.

## Política central de efectos

Cada operación debería declarar metadatos como:

- `ReadsSystem`
- `WritesDisk`
- `WritesRegistry`
- `ChangesServices`
- `UsesNetwork`
- `RequiresElevation`
- `MayReboot`
- `PotentiallyDestructive`
- `CanRollback`

Antes de ejecutar, un motor central comprobaría el contexto. No debería depender de que cada función recuerde hacer `if ($DryRun)` en el lugar correcto.

## Cambios concretos que estudiaría

- Resolver el modo de ejecución al principio del proceso.
- Evitar cargar o inicializar winget si la acción no lo necesita.
- No actualizar fuentes durante diagnóstico, ayuda, selftest o construcción de un plan.
- No tocar `HKCU\Console` en pruebas.
- No ejecutar `flushdns` en un escaneo.
- Usar un proveedor de almacenamiento en memoria para selftests.
- Permitir opcionalmente que un dry-run exporte un plan solo si el usuario elige una ruta explícita.

## Criterios de aceptación

En una VM limpia, comparar antes y después:

- Registro.
- Servicios.
- Tareas.
- Archivos fuera de una ruta temporal autorizada.
- Fuentes winget.
- Eventos relevantes.
- Conexiones de red.

El resultado esperado para un modo declarado «sin cambios» sería diferencia cero, salvo artefactos explícitamente solicitados por el usuario.

---

# 15. Línea de trabajo 3 — Capa segura para ejecutar procesos externos

## Problema que resolvería

WINZARD llama a muchas herramientas con semánticas diferentes:

- `winget`
- `dism.exe`
- `robocopy`
- `sfc.exe`
- `chkdsk.exe`
- `oscdimg.exe`
- `schtasks` o API de tareas
- utilidades de red y drivers

Si cada ruta concatena cadenas e interpreta resultados por su cuenta, aparecen inyección, quoting incorrecto y falsos éxitos.

## Qué construiría

Una función o módulo único similar conceptualmente a `Invoke-WpiProcess`, con:

- `FilePath` separado de `ArgumentList`.
- Prohibición de `cmd.exe /c` salvo caso excepcional documentado.
- Captura separada de stdout y stderr.
- Timeout.
- Cancelación.
- Tabla específica de códigos de éxito por herramienta.
- Redacción de secretos al registrar argumentos.
- Identificador de operación.
- Duración.
- Contexto de elevación.
- Resultado estructurado.

Ejemplo conceptual de resultado:

```powershell
[pscustomobject]@{
    Status = 'Succeeded' # Succeeded, Warning, Failed, Skipped, Unknown
    ExitCode = 0
    Tool = 'dism.exe'
    StartedAt = $started
    Duration = $elapsed
    StdOutPath = $stdoutPath
    StdErrPath = $stderrPath
    Verification = $verification
}
```

## Casos especiales

- **Robocopy:** interpretar `0..7` según la operación y tratar `>=8` como fallo, sin asumir que todos los códigos no cero son iguales.
- **Winget:** combinar exit code, salida y comprobación posterior del paquete.
- **DISM:** no pasar argumentos controlables por `cmd.exe`; verificar estado de imagen después.
- **SFC:** delimitar resultados de la ejecución actual.
- **OSCDIMG:** comprobar existencia, firma/origen permitido, salida y presencia del ISO final.

## Pruebas necesarias

- Argumentos con espacios, comillas, `&`, `|`, `<`, `>`, `^`, `%`, `!`, rutas UNC y Unicode.
- Procesos que devuelven 0, 1, códigos positivos especiales, timeout y terminación abrupta.
- Secretos que nunca deben aparecer en logs.

---

# 16. Línea de trabajo 4 — Elevación, temporales, ACL y fronteras de confianza

## Objetivo

Reducir al mínimo el código que corre elevado y eliminar rutas sustituibles entre la validación y la ejecución.

## Cambios que consideraría

### Elevación por unidad de trabajo

- Mantener GUI, inventario, búsqueda y planificación sin elevación.
- Elevar solo un ejecutor estrecho con un contrato de entrada validado.
- Mostrar por qué se solicita UAC y qué acciones contiene el plan.
- Evitar relanzar scripts arbitrarios desde ubicaciones controlables.

### Temporales seguros

- Crear una carpeta única con GUID mediante API segura.
- Aplicar ACL que permita acceso únicamente al usuario actual, administradores y SYSTEM según necesidad.
- Comprobar que la ruta no sea reparse point.
- Abrir y escribir de forma que se minimice la sustitución.
- Calcular hash después de escribir y verificar justo antes de usar si existe cambio de contexto.
- Limpiar mediante `finally`.

### Tareas programadas

- Preferir un componente estable instalado en una ubicación protegida, no scripts sueltos editables.
- Guardar definición, versión y hash.
- Verificar owner y DACL antes de registrar y antes de ejecutar.
- Evitar argumentos capaces de seleccionar un script arbitrario.
- Eliminar tareas obsoletas de forma controlada.

## Qué probaría Opus 5 en VM

- Usuario estándar intentando reemplazar scripts.
- Directorios con herencia permisiva.
- Junctions creados antes y durante la elevación.
- Colisiones y ejecuciones simultáneas.
- Cambio del archivo entre hash y ejecución.
- Instalación y desinstalación de tareas.

---

# 17. Línea de trabajo 5 — Modelo único de resultados y códigos de salida

## Problema

El estado comunicado al usuario no siempre representa el resultado real. Esto afecta GUI, CLI, informes y reanudación de fases.

## Modelo que propondría investigar

Usar estados explícitos y no booleanos ambiguos:

- `NotStarted`
- `Planned`
- `Running`
- `Succeeded`
- `SucceededWithWarnings`
- `Skipped`
- `Failed`
- `Cancelled`
- `Unknown`

Una fase solo debería entrar en `Completed` cuando su contrato de éxito se haya cumplido. «Intentada» debería ser otro dato, no sinónimo de completada.

## Códigos de salida globales sugeridos

Podría estudiarse un contrato como:

| Código | Significado |
|---:|---|
| 0 | Todo lo solicitado terminó correctamente |
| 1 | Error de uso o parámetros |
| 2 | Operación cancelada |
| 3 | Completado con advertencias o acciones omitidas |
| 4 | Fallo parcial |
| 5 | Fallo fatal de inicialización o seguridad |
| 3010 | Reinicio requerido, si se decide conservar semántica Windows |

La cifra exacta puede variar, pero debe existir una especificación única.

## Criterios de aceptación

- Un fallo de fase nunca aparece como `OK`.
- El informe y el exit code concuerdan.
- GUI y CLI muestran el mismo resultado estructurado.
- La reanudación no omite fases fallidas por haber sido «intentadas».
- Los errores inesperados se clasifican como `Unknown` o `Failed`, nunca como éxito.

---

# 18. Línea de trabajo 6 — Operaciones transaccionales y reversión real

## Qué cambiaría

Para tweaks, debloat, servicios, registro, tareas y red, cada acción debería implementar idealmente:

1. `TestPrecondition`
2. `CaptureState`
3. `Apply`
4. `Verify`
5. `Rollback`
6. `VerifyRollback`

El journal se escribiría después de capturar estado y se confirmaría solamente después de aplicar y verificar.

## Formato de journal premium

Cada entrada podría incluir:

- ID estable de acción.
- Versión del esquema.
- Fecha y usuario.
- Equipo y edición de Windows.
- Estado anterior serializado.
- Acción solicitada.
- Resultado del proceso.
- Verificación posterior.
- Estado de rollback.
- Hash de los datos críticos.

## Diferencias importantes

- **Deshacer** debería restaurar el valor anterior.
- **Restablecer a valores recomendados** puede seguir existiendo, pero con otro nombre.
- Si una acción no es reversible, debe decirlo antes de ejecutarse.
- Si solo es parcialmente reversible, debe indicar qué queda fuera.

## Casos a tratar con cautela

- OneDrive.
- Paquetes Appx con dependencias.
- Componentes de Xbox.
- Reset de red.
- Windows Update y eliminación de cachés.
- `DISM /ResetBase`.
- Drivers.
- Limpieza de eventos o evidencia diagnóstica.

---

# 19. Línea de trabajo 7 — Rediseño seguro del constructor ISO

## Separación que propondría

Dividir el flujo en etapas independientes:

1. Validar configuración.
2. Validar medios fuente.
3. Preparar workspace único.
4. Copiar y verificar archivos.
5. Integrar payload WPI.
6. Integrar drivers opcionales.
7. Generar `autounattend.xml`.
8. Ejecutar validaciones de seguridad.
9. Construir ISO.
10. Verificar ISO terminada.
11. Limpiar y emitir manifiesto.

Cada etapa debería producir un resultado estructurado y detener la siguiente si falla.

## Mejoras críticas

### Workspace

- Ruta única por ejecución, no `C:\_wpichk` fija.
- Comprobación de espacio libre.
- Prohibición de reparse points inesperados.
- Limpieza en `finally`.
- Recuperación de montajes huérfanos identificados por WINZARD.

### Copia

- Interpretar correctamente `robocopy`.
- Verificar que archivos esenciales y payload existen después de copiar.
- Comparar tamaño y, en elementos críticos, hash.

### Autounattend

- Separar plantillas:
  - instalación asistida segura;
  - VM desechable;
  - automatización avanzada.
- El modo que borra disco debería vivir detrás de una sección «Laboratorio/Destructivo».
- Incluir una marca visible en nombre del ISO y manifiesto, por ejemplo `ERASES_DISK0`.
- No presentar como secreto ninguna contraseña embebida.
- Ofrecer cuenta sin contraseña temporal, creación diferida o solicitud en primer arranque cuando sea viable.

### Drivers

- Firmados por defecto.
- Inventario de proveedor, clase, versión y firma.
- `ForceUnsigned` solo en modo laboratorio, con doble confirmación.
- Verificación en VM con Secure Boot cuando corresponda.

### OSCDIMG

- Invocación directa, sin `_oscdimg.cmd` generado.
- Ruta de herramienta validada.
- Argumentos separados.
- Manifiesto de construcción con versión y hashes.

## Verificación del ISO final

El verificador debería fallar si falta cualquier requisito configurado, incluido `autounattend.xml` cuando el modo lo requiera. También podría comprobar:

- Estructura de arranque BIOS/UEFI.
- Payload WPI.
- Archivo de configuración.
- Scripts de SetupComplete.
- XML válido.
- Referencias a archivos existentes.
- Ausencia de secretos no aprobados.
- Hash final.
- Arranque de humo en VM.

---

# 20. Línea de trabajo 8 — Autoactualización y cadena de suministro

## Opción conservadora

Hasta disponer de un canal firmado, **retiraría o desactivaría temporalmente la autoactualización ejecutable**. Mantendría solamente «Comprobar si existe una versión nueva» y abriría la página oficial para que el usuario decida.

## Opción premium

Un sistema de actualización serio podría usar:

- HTTPS obligatorio.
- Lista cerrada de hosts.
- Manifiesto versionado.
- Hash SHA-256 del artefacto.
- Firma del manifiesto con una clave fuera del repositorio.
- Firma Authenticode del script o paquete.
- Protección contra downgrade.
- Descarga a archivo temporal seguro.
- Verificación antes de reemplazar.
- Reemplazo atómico.
- Copia de rollback.
- Registro de versión anterior y nueva.

## Dependencias y CI

- Fijar GitHub Actions por SHA completo.
- Declarar permisos mínimos.
- Generar SBOM de releases si el formato de distribución lo permite.
- Publicar hashes y firmas en un canal independiente o verificable.
- Evitar dependencias `latest` cuando la reproducibilidad sea importante.
- Documentar claramente qué descargas realiza WINZARD y desde dónde.

---

# 21. Línea de trabajo 9 — Winget, catálogos y conectores remotos

## Qué investigaría

- Cuándo se resuelve, instala o actualiza winget.
- Qué operaciones actualizan fuentes automáticamente.
- Qué comandos dependen de red.
- Cómo se valida un catálogo remoto.
- Qué pasa si winget no está disponible, devuelve salida localizada o cambia su esquema.

## Mejoras sugeridas

### Winget bajo demanda

- No inicializar winget al arrancar si la función solicitada no lo necesita.
- Separar «comprobar disponibilidad», «instalar winget» y «actualizar fuentes».
- Pedir consentimiento antes de instalar o alterar fuentes.
- Cachear información con una caducidad visible.

### Catálogo

- Esquema JSON versionado y validado.
- Campos permitidos estrictos.
- No permitir comandos arbitrarios dentro del catálogo.
- Identificadores de paquete, no fragmentos de shell.
- Firma o hash del catálogo remoto.
- Fuente y fecha visibles.
- Fallback a catálogo local conocido.

### Comprobación posterior

Para instalar, actualizar o eliminar, no bastaría con el exit code. Debería verificarse el estado real del paquete cuando sea posible.

---

# 22. Línea de trabajo 10 — Debloat y tweaks con calidad profesional

## Modelo de riesgo por acción

Cada tweak o elemento de debloat debería tener:

- ID estable.
- Nombre y explicación.
- Versiones de Windows compatibles.
- Requisitos.
- Nivel de riesgo.
- Necesidad de reinicio.
- Impacto en privacidad, seguridad, gaming o servicios.
- Estado previo detectable.
- Método de aplicación.
- Método de verificación.
- Método de rollback.
- Limitaciones conocidas.

## Perfiles sugeridos

En vez de una lista plana enorme, plantearía perfiles transparentes:

- **Seguro:** cambios reversibles y de bajo riesgo.
- **Privacidad equilibrada:** evita romper Store, Xbox, impresión o actualizaciones.
- **Gaming:** cambios medidos y explicados; nada de mitos no verificables.
- **Empresa:** conserva gestión, BitLocker, Defender y políticas.
- **Laboratorio:** opciones agresivas claramente separadas.

## Qué retiraría o reformularía

- Tweaks cuyo beneficio no se pueda demostrar o cuya evidencia sea obsoleta.
- Ajustes duplicados o que Windows revierte automáticamente.
- Claims como «más FPS» sin medición.
- Eliminación irreversible presentada como reversible.
- Acciones que deshabiliten seguridad sin advertencia y justificación específica.

## Mejora premium

Mostrar una comparación previa:

```text
Estado actual → Estado propuesto → Riesgo → Reinicio → Rollback disponible
```

Tras aplicar, ejecutar una verificación y permitir exportar el plan y el resultado.

---

# 23. Línea de trabajo 11 — Suite de reparación y sus 17 fases

## Enfoque recomendado

No asumir que «más reparaciones» significa «mejor». Muchas fases son costosas, borran evidencia o cambian componentes que quizá no estaban dañados.

## Clasificación que estudiaría

- Diagnóstico únicamente.
- Reparación segura y específica.
- Reparación amplia.
- Acción destructiva o difícil de revertir.
- Acción que requiere reinicio.
- Acción que requiere fuente externa.

## Mejoras

- Ejecutar primero diagnóstico y solo proponer fases justificadas.
- Hacer que `/plan` muestre exactamente qué fases correrían y por qué.
- Corregir la máquina de estados de fases.
- Conservar resultados parciales, pero no marcarlos como completados.
- Evitar resetear Windows Update, red, firewall o cachés como respuesta genérica.
- Preservar logs y evidencia antes de limpiar.
- Registrar la fuente DISM exacta y validarla contra edición, idioma, arquitectura y build.
- Tratar `/resetbase` y `/fwreset` como opciones de alto impacto.
- Aclarar qué fases no admiten rollback.

## Pruebas de VM sugeridas

Crear snapshots con fallos conocidos:

- Component store sano y corrupto.
- Windows Update detenido o roto.
- Fuente DISM correcta, incorrecta y maliciosa.
- Red funcional y red rota.
- Disco con y sin errores simulables.
- Usuario estándar frente a administrador.
- Cancelación durante cada fase.
- Reinicio pendiente.

---

# 24. Línea de trabajo 12 — Diagnóstico basado en evidencia

## Cambios que haría

### Estado desconocido como primera clase

Si WMI, CIM, SMART o un servicio no responde, el resultado debe ser `Unknown`, no `OK`.

### Multidisco

Enumerar todos los discos y mostrar:

- Bus y modelo.
- Estado operativo.
- Salud reportada.
- Fiabilidad cuando esté disponible.
- Limitación de SMART según controlador/USB/RAID.

### Memoria

Distinguir:

- Sin eventos encontrados.
- Diagnóstico nunca ejecutado.
- Consulta no disponible.
- Error detectado.

### SFC y DISM

Capturar hora de inicio, salida propia y eventos posteriores. No atribuir todo CBS histórico a la ejecución actual.

### Resultado premium

Cada tarjeta de diagnóstico debería indicar:

- Dato observado.
- Fuente del dato.
- Hora.
- Confianza.
- Limitaciones.
- Siguiente acción sugerida.

---

# 25. Línea de trabajo 13 — Drivers y hardware

## Mejoras propuestas

- Inventariar drivers antes de exportar o integrar.
- Registrar proveedor, clase, versión, fecha y firma.
- Usar temporales seguros.
- Verificar el resultado real de exportación.
- Evitar elevar un script temporal fijo.
- Separar exportación, respaldo, integración y restauración.
- No prometer que un respaldo garantiza restauración en otro hardware.
- Detectar paquetes no firmados y bloquearlos por defecto.
- Mostrar incompatibilidades con arquitectura y versión de Windows.

## Función premium posible

Crear un «paquete de drivers verificable» con:

- Manifiesto.
- Hashes.
- Metadatos.
- Firma si está disponible.
- Equipo de origen.
- Versión de Windows.
- Advertencia de portabilidad.

---

# 26. Línea de trabajo 14 — Privacidad del paquete de soporte

## Diseño sugerido

Antes de crear el ZIP, mostrar categorías seleccionables:

- Identidad del equipo.
- Usuario.
- Red e IP.
- Procesos.
- Programas instalados.
- Tareas y arranque.
- Logs de WINZARD.
- Eventos de Windows.
- Hardware.

## Redacción

- Sustituir usuario, nombre de equipo, dominio, IP y rutas personales por tokens consistentes.
- Permitir previsualizar el inventario de archivos.
- Crear un `CONTENTS.md` dentro del ZIP.
- Avisar de que todavía puede contener información sensible.
- No subir automáticamente nada.

## Corrección concreta

Reparar el patrón inglés que busca `Informe` cuando el archivo se llama `Report_<timestamp>.html` y añadir una prueba que compruebe el contenido del ZIP en ambos idiomas.

---

# 27. Línea de trabajo 15 — Modularización progresiva sin gran reescritura

## Qué evitaría

No recomendaría reescribir las casi 19.000 líneas de una vez. Una reescritura total puede perder compatibilidad y reintroducir errores.

## Estrategia de extracción

Extraería por fronteras estables:

```text
src/
  Wpi.Core.psm1
  Wpi.Execution.psm1
  Wpi.Security.psm1
  Wpi.Results.psm1
  Wpi.Winget.psm1
  Wpi.Tweaks.psm1
  Wpi.Debloat.psm1
  Wpi.Diagnostics.psm1
  Wpi.Repair.psm1
  Wpi.Drivers.psm1
  Wpi.Iso.psm1
  Wpi.Tasks.psm1
  Wpi.Reporting.psm1
  Wpi.Localization.psm1
```

Esta es solo una posibilidad; Opus 5 debería estudiar las dependencias reales antes de fijar nombres o límites.

## Orden de extracción que elegiría

1. Resultados y logging.
2. Ejecución de procesos.
3. Validación y seguridad.
4. Configuración.
5. ISO y drivers.
6. Winget, tweaks y debloat.
7. Diagnóstico y reparación.
8. UI al final.

Así, cada extracción aporta seguridad inmediatamente y reduce el riesgo de romper la GUI.

---

# 28. Línea de trabajo 16 — Configuración, idiomas y documentación como fuente única

## Configuración

- Añadir versión de esquema.
- Validar tipos y valores.
- Migrar configuraciones antiguas explícitamente.
- Distinguir valores por defecto de preferencias del usuario.
- No forzar `Lang = es` en una configuración distribuida si se desea autodetección.
- Guardar secretos fuera del JSON o no guardarlos.

## Idiomas

- Claves idénticas en ES/EN.
- Prueba automática de claves faltantes.
- Fallback controlado.
- No incrustar prefijos lingüísticos en lógica de archivos, como `Informe` frente a `Report`.

## Documentación generada

Generaría automáticamente desde metadatos:

- Lista de parámetros.
- Ayuda de suites.
- Conteo de aplicaciones.
- Conteo de tweaks.
- Versión.
- Pasos del constructor ISO.
- Matriz de riesgo.

Esto eliminaría discrepancias como 350/352/360/362, 40/86 y 3.1/3.2.

## Claims

Cambiaría absolutos por lenguaje verificable:

- «Diseñado para ser reversible cuando la acción lo permite».
- «Dry-run no ejecuta acciones del plan; puede generar un informe si se solicita».
- «La disponibilidad de winget depende de Microsoft, red y versión del sistema».
- «Las operaciones de red se detallan antes de ejecutarse».

---

# 29. Línea de trabajo 17 — CI, pruebas y laboratorio de VM

## Pruebas estáticas rápidas

En cada cambio:

- Parseo PowerShell.
- PSScriptAnalyzer con reglas justificadas.
- Validación de JSON y PSD1.
- Enlaces Markdown.
- Claves de traducción.
- Generación reproducible de suites.
- Detección de secretos.
- Búsqueda de patrones peligrosos como `cmd /c` con datos variables.

## Pruebas unitarias

Pester podría cubrir:

- Parseo de argumentos.
- Matrices de códigos de salida.
- Generación de planes.
- Validación de configuración.
- Redacción de datos.
- Estados de fase.
- Interpretación de robocopy.
- Construcción de argumentos DISM sin shell.

## Pruebas de integración seguras

Usar dobles o ejecutables simulados para winget, DISM y OSCDIMG, capaces de devolver códigos y salidas controladas.

## Laboratorio de VM

Para operaciones reales:

- Matriz de Windows 10/11 y builds soportadas.
- Usuario estándar y administrador.
- Snapshots antes de cada caso.
- Red desconectada, lenta y manipulada.
- Disco con espacio insuficiente.
- Reinicio pendiente.
- Cancelación.
- Ejecución concurrente.
- ISO en Hyper-V o plataforma equivalente.

## Release gate

No publicaría una versión estable si falla cualquiera de estos puntos:

- Parámetro inválido ejecuta acción.
- Dry-run cambia sistema.
- Fallo interno devuelve éxito.
- ISO incompleta pasa verificación.
- Temporal elevado es sustituible por usuario estándar.
- Autoactualización acepta artefacto no firmado.
- Rollback no restaura el estado capturado en acciones declaradas reversibles.

---

# 30. Línea de trabajo 18 — Observabilidad y registros premium

## Qué mejoraría

- Un ID de correlación por sesión.
- Un ID por acción.
- Logs estructurados JSON además del informe legible.
- Niveles `Debug`, `Info`, `Warning`, `Error`, `Security`.
- No registrar contraseñas, tokens ni argumentos sensibles.
- Diferenciar resultado de proceso y verificación funcional.
- Resumen final con fallos y acciones pendientes.

## Informe final ideal

- Qué se solicitó.
- Qué se planificó.
- Qué se omitió y por qué.
- Qué se ejecutó.
- Qué se verificó.
- Qué requiere reinicio.
- Qué puede revertirse.
- Qué quedó en estado desconocido.
- Código de salida global.

---

# 31. Línea de trabajo 19 — Experiencia premium de usuario

## Centro de seguridad previo

Antes de ejecutar un lote, mostrar:

- Número de acciones.
- Elevación necesaria.
- Descargas y hosts.
- Cambios de registro, servicios y tareas.
- Reinicios.
- Acciones irreversibles.
- Tiempo estimado como rango, no promesa exacta.
- Espacio necesario.

## Modos de usuario

### Modo seguro

- Solo acciones de bajo riesgo y reversibles.
- Confirmaciones claras.
- Sin drivers no firmados.
- Sin borrado automático de disco.
- Sin resets amplios salvo diagnóstico que los justifique.

### Modo experto

- Más control y parámetros.
- Explicaciones técnicas.
- Exportación e importación de planes.
- Requiere confirmación adicional para alto impacto.

### Modo laboratorio

- Operaciones destructivas.
- ISO que borra disco.
- Drivers no firmados.
- Pruebas y opciones experimentales.
- Señalización visual permanente y distinta.

## Accesibilidad

También investigaría:

- Navegación completa por teclado.
- Lectores de pantalla.
- Escalado DPI.
- Contraste.
- No depender solo del color para estados.
- Textos largos ES/EN sin recortes.
- Cancelación segura y progreso real.

---

# 32. Qué quitaría, congelaría o simplificaría

No todo debe conservarse por tener ya código escrito. Consideraría estas decisiones, sujetas a investigación:

## Retirada temporal

1. **Autoactualización ejecutable**, hasta tener firma y manifiesto verificable.
2. **`ForceUnsigned` por defecto**, manteniéndolo solo en laboratorio si sigue siendo necesario.
3. **Promesas de dry-run inocuo**, hasta que pueda demostrarse.
4. **Modo VM destructivo dentro del flujo normal**, moviéndolo a un área de laboratorio.

## Eliminación técnica

1. Generación de `_oscdimg.cmd` desde configuración.
2. Uso de `cmd.exe /c` con argumentos variables para DISM.
3. Temporales de nombre fijo que luego se elevan.
4. Defaults que convierten valores inválidos en operaciones amplias.
5. Registro anticipado de tweaks como completados.
6. Tratamiento de códigos inesperados como `OK`.

## Simplificación

1. Unificar suites ES/EN sobre lógica común y separar solamente recursos traducibles.
2. Unificar resultado, logging y exit codes.
3. Generar ayuda y documentación desde metadatos.
4. Reducir tweaks redundantes o sin evidencia.
5. Evitar resets globales cuando exista una reparación específica.
6. Mantener una única fuente canónica de versión.

## Funciones que conservaría y reforzaría

- Catálogo de aplicaciones.
- Diagnóstico.
- Informes locales.
- Constructor ISO, después de endurecerlo.
- Suites de reparación, haciéndolas selectivas.
- Soporte bilingüe.
- Perfiles, transformándolos en planes transparentes.
- Exportación de drivers con manifiesto y seguridad.

---

# 33. Arquitectura objetivo de referencia

Sin imponer una tecnología nueva, visualizaría cinco capas:

```text
┌───────────────────────────────────────────┐
│ GUI WPF / CLI / Automatización            │
├───────────────────────────────────────────┤
│ Planificador y políticas de seguridad     │
├───────────────────────────────────────────┤
│ Operaciones de dominio                    │
│ Apps · Tweaks · Repair · Drivers · ISO    │
├───────────────────────────────────────────┤
│ Ejecución · Elevación · Resultados · Undo │
├───────────────────────────────────────────┤
│ Windows · Winget · DISM · Registro · FS   │
└───────────────────────────────────────────┘
```

Reglas clave:

- La GUI no ejecuta comandos directamente.
- Las operaciones no construyen shells arbitrarias.
- El planificador conoce riesgos y efectos.
- El ejecutor devuelve resultados estructurados.
- El journal captura estado antes y confirma después.
- La elevación acepta operaciones conocidas, no texto libre.

---

# 34. Planning de referencia por fases

Este planning es una propuesta para que Opus 5 la contraste; no implica que todas las fases deban ejecutarse tal cual.

## Fase 0 — Baseline y congelación de riesgo

**Objetivo:** conocer exactamente qué existe antes de modificarlo.

Posibles entregables:

- Mapa de funciones y dependencias.
- Inventario real de parámetros.
- Matriz de efectos laterales.
- Lista de comandos externos.
- Matriz de privilegios.
- Catálogo de tareas y temporales.
- Baseline de artefactos generados.
- Decisión sobre versiones de Windows soportadas.

No añadiría nuevas funcionalidades en esta fase.

## Fase 1 — Seguridad P0

**Objetivo:** cerrar vías de ejecución inesperada o elevada insegura.

Orden razonable:

1. Argumentos estrictos.
2. Guardas antes de inicialización.
3. Desactivar autoactualización insegura.
4. Eliminar `cmd /c` variable.
5. Temporales seguros.
6. ACL y tareas.
7. Protecciones de ISO destructiva.
8. Drivers firmados por defecto.

Salida esperada: ninguna entrada inválida amplía acciones y ninguna ruta elevada depende de un archivo sustituible conocido.

## Fase 2 — Fiabilidad de resultados

**Objetivo:** que cada resultado sea verdadero y automatizable.

1. Modelo de resultados.
2. Capa de procesos externos.
3. Códigos de salida.
4. Estados de las 17 fases.
5. Robocopy.
6. Verificador ISO.
7. Winget y debloat.
8. Diagnósticos `Unknown`.

## Fase 3 — Reversión y transacciones

**Objetivo:** reducir daño y permitir recuperación real.

1. Journal versionado.
2. Captura de estado.
3. Verificación posterior.
4. Rollback real.
5. `try/finally` en políticas, montajes y temporales.
6. Clasificación de acciones no reversibles.

## Fase 4 — Modularización progresiva

**Objetivo:** facilitar mantenimiento sin reescritura total.

- Extraer ejecución, resultados, seguridad y configuración.
- Mantener adaptadores para compatibilidad.
- Añadir pruebas antes de extraer cada área.

## Fase 5 — UX, privacidad y documentación

**Objetivo:** alinear promesas con comportamiento.

- Centro de seguridad.
- Modos seguro/experto/laboratorio.
- Redacción de soporte.
- Ayuda generada.
- Versiones y conteos únicos.
- Advertencias de credenciales e ISO.
- Accesibilidad.

## Fase 6 — Certificación interna de release

**Objetivo:** demostrar, no asumir.

- Matriz VM.
- Pruebas destructivas con snapshots.
- Pruebas negativas.
- Reproducibilidad de artefactos.
- Segunda auditoría de seguridad.
- Release candidate sin hallazgos P0/P1 abiertos.

---

# 35. Matriz resumida de prioridad

| Área | Prioridad | Acción de referencia | Validación principal |
|---|---|---|---|
| Argumentos desconocidos | P0 | Rechazo estricto | Pruebas negativas |
| Dry/selftest | P0 | Separar Discover/Plan/Apply | Diff de VM antes/después |
| `/source:` y shell | P0 | Ejecución directa con argumentos | Fuzz de caracteres y VM |
| Temporales elevados | P0 | GUID + ACL + no reparse | Usuario estándar atacante |
| Autoactualización | P0 | Desactivar o firmar | Artefacto alterado rechazado |
| ISO borra disco 0 | P0 | Aislar y reforzar confirmación | Revisión UX + VM |
| Estados falsamente OK | P0 | Modelo estructurado | Exit code e informe coherentes |
| Robocopy/ISO incompleta | P0 | Códigos y requisitos fatales | Copia fallida bloquea build |
| Contraseñas ISO | P0/P1 | Evitar o advertir y limpiar | Escaneo de secretos |
| `ForceUnsigned` | P1 | Desactivado por defecto | ISO con Secure Boot |
| Undo | P1 | Capturar estado real | Apply/rollback comparado |
| Diagnóstico | P1 | Estado Unknown y multidisco | Casos sin proveedor/datos |
| Paquete soporte | P1 | Redacción y consentimiento | Inspección ZIP ES/EN |
| CI supply chain | P1 | SHA y permisos mínimos | Revisión workflow |
| Modularización | P2 | Extracción progresiva | Tests de regresión |
| Documentación | P2 | Generación desde metadatos | Drift check en CI |
| UX premium | P2 | Centro de seguridad y modos | Pruebas de usuario |

---

# 36. Criterios de «terminado» para una versión estable

Yo no consideraría estable una nueva versión hasta poder demostrar como mínimo:

1. Ningún argumento desconocido se ignora.
2. Ningún valor inválido ejecuta una acción por defecto.
3. Dry-run no produce cambios no declarados.
4. Las acciones de red requieren una función que las justifique.
5. No se concatenan entradas variables en shells elevadas.
6. Los temporales elevados no son sustituibles por un usuario estándar.
7. Las tareas verifican rutas y permisos seguros.
8. Un fallo real no se registra como `OK`.
9. CLI, GUI e informes concuerdan.
10. ISO incompleta nunca pasa la verificación.
11. El modo de borrado de disco está aislado y señalizado.
12. Los secretos no se registran y su inclusión en ISO se advierte.
13. Drivers no firmados están bloqueados por defecto.
14. Las acciones declaradas reversibles restauran el estado capturado.
15. Las acciones no reversibles se identifican antes de ejecutar.
16. Los diagnósticos distinguen sano, fallo y desconocido.
17. ES y EN generan informes funcionalmente equivalentes.
18. Los artefactos publicados tienen hash y firma verificables.
19. Las pruebas de VM cubren reinicios, cancelación y fallo parcial.
20. La documentación se corresponde con el comportamiento probado.

---

# 37. Preguntas que Opus 5 debería resolver antes del planning definitivo

## Producto

- ¿Quién es el usuario principal: técnico, usuario doméstico o laboratorio?
- ¿Qué versiones y ediciones de Windows se soportan realmente?
- ¿Qué compatibilidad CLI debe conservarse?
- ¿Qué operaciones justifican formar parte del producto y cuáles son demasiado peligrosas?

## Seguridad

- ¿Cuáles son las ACL reales de cada script usado por tareas?
- ¿Puede un usuario estándar sustituir algún helper antes de la elevación?
- ¿Existe una clave y proceso viable para firmar releases?
- ¿Qué hosts de red son imprescindibles?
- ¿Hay datos controlables que todavía lleguen a `cmd.exe`, `powershell.exe -Command` o archivos CMD generados?

## Fiabilidad

- ¿Qué códigos devuelve cada herramienta en los Windows soportados?
- ¿Cómo se verifica el éxito funcional después del exit code?
- ¿Qué acciones pueden reanudarse de forma segura?
- ¿Qué pasa si se cierra WINZARD o se reinicia Windows a mitad de una fase?

## Reversión

- ¿Qué acciones guardan hoy el estado anterior?
- ¿Cuáles son irreversibles por naturaleza?
- ¿Qué datos se pierden al resetear cachés o componentes?
- ¿Se puede probar rollback en diferentes builds?

## ISO

- ¿El modo VM está pensado exclusivamente para entornos desechables?
- ¿Puede evitarse almacenar contraseña?
- ¿Cómo se selecciona el disco de destino?
- ¿Cómo se prueba BIOS, UEFI, Secure Boot y arquitecturas?

## Arquitectura

- ¿Qué funciones tienen más acoplamiento global?
- ¿Qué módulo puede extraerse primero sin romper la GUI?
- ¿Qué estado global necesita convertirse en contexto explícito?
- ¿Cómo se mantienen artefactos generados reproducibles?

---

# 38. Entregables recomendados de Opus 5 antes de implementar

Para conseguir un buen planning, sería útil que Opus 5 devolviera primero:

1. **Validación independiente de hallazgos**, con confirmado/condicional/descartado.
2. **Mapa de arquitectura real**, incluidos puntos de elevación y red.
3. **Matriz de efectos laterales** por comando y opción.
4. **Matriz de riesgos y dependencias**.
5. **Decisiones de producto** sobre qué conservar, retirar o aislar.
6. **ADRs breves** para ejecución de procesos, resultados, elevación, journal y actualización.
7. **Plan por cambios pequeños**, evitando una gran reescritura.
8. **Plan de compatibilidad y migración**.
9. **Plan de pruebas estáticas, simuladas y de VM**.
10. **Criterios de aceptación y rollback de cada lote**.
11. **Estimación de riesgo**, no solo de tiempo.
12. **Puntos que requieren decisión del propietario** antes de editar.

Después de esa investigación, el propietario podría aprobar fases concretas y pedir implementación por lotes verificables.

---

# 39. Esquema de ideas premium adicionales

Estas ideas no son necesarias para corregir la auditoría, pero podrían diferenciar una versión futura:

## Planes firmados y exportables

Permitir exportar un plan legible y estructurado, revisarlo en otro equipo y ejecutarlo solo si no fue alterado.

## Comparación antes/después

Crear un resumen de cambios de:

- Registro.
- Servicios.
- Tareas.
- Paquetes.
- Drivers.
- Estado de componentes.

## Detector de riesgo contextual

Advertir si el equipo es:

- Unido a dominio.
- Administrado por empresa.
- Servidor.
- Máquina con BitLocker.
- Equipo con reinicio pendiente.
- Equipo sin punto de restauración disponible.

## Modo offline verificable

Permitir usar catálogos y paquetes descargados previamente con hashes, sin necesidad de confiar en contenido remoto durante la reparación.

## Historial local auditable

Mostrar sesiones anteriores, resultados, cambios, rollback disponible y versión de WINZARD usada.

## Health score prudente

Si se implementa una puntuación de salud, debería ser explicable y no ocultar estados desconocidos. Cada punto tendría una evidencia visible.

## Plugin model limitado

Si algún día se admiten extensiones, deberían ser manifiestos declarativos y firmados, no scripts arbitrarios cargados automáticamente.

## Release reproducible

Generar suites, manuales, hashes y artefactos desde una fuente canónica en CI, verificando que el repositorio no contiene outputs desactualizados.

---

# 40. Recomendación final para el siguiente responsable técnico

La mayor oportunidad de WINZARD no está ahora mismo en añadir más funciones. Está en convertir sus muchas funciones existentes en operaciones:

- predecibles;
- verificables;
- seguras por defecto;
- transparentes;
- recuperables;
- automatizables con códigos de salida fiables.

La estrategia que yo seguiría sería:

1. Congelar temporalmente la expansión.
2. Confirmar los hallazgos sobre el commit actual.
3. Resolver P0 con cambios pequeños y pruebas negativas.
4. Introducir resultados estructurados y ejecución segura.
5. Hacer reales el dry-run y el rollback.
6. Endurecer ISO, drivers, tareas y actualización.
7. Modularizar gradualmente.
8. Alinear UX y documentación.
9. Validar en una matriz de VM.
10. Realizar una segunda auditoría antes de declarar estable.

> **Opus 5 no debería asumir que todas las propuestas de este documento son obligatorias ni empezar una reescritura completa. Debería investigarlas, contrastarlas con el código actual, presentar discrepancias y convertir únicamente las conclusiones confirmadas en un planning técnico priorizado para aprobación.**

---

# 41. Nota de integridad de la auditoría

Durante la auditoría original:

- no se modificó WINZARD;
- no se ejecutaron reparaciones;
- no se montaron ni generaron imágenes;
- no se llamó a winget o DISM;
- no se hicieron llamadas de red;
- no se probaron ataques o carreras en el sistema real.

Por ello, los hallazgos estáticos están respaldados por el código auditado, mientras que las hipótesis de explotación condicionadas a ACL, reparse points, carreras o entorno deben verificarse en un laboratorio aislado.

**Fin del documento.**
