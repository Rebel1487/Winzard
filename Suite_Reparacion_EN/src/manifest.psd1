# manifest.psd1 | Manifiesto de configuracion canonico de la Suite (Task 1.4, Req 14.1).
# Fuente unica de verdad para constantes (version, retencion de logs, validez de checkpoint,
# nivel de terminal virtual deseado) y para los titulos/"por que" de las 17 fases (de :title_of).
# Lo consume el generador (build/generar.ps1, Task 2). NO se distribuye ni se ejecuta directamente.
@{
    WPI_VERSION             = '3.1'
    LOG_RETENTION           = 10
    CHECKPOINT_MAX_AGE_DAYS = 7
    VT_LEVEL_DESIRED        = 1

    # Titulos y "por que" de las 17 fases (00..16), VERBATIM de :title_of en lib_wpi.cmd.
    PHASES = @(
        @{ Id = '00'; Title = 'Diagnostico y triage'; Why = 'Mira discos, espacio y eventos, y detecta la causa raiz.' }
        @{ Id = '01'; Title = 'Punto de restauracion'; Why = 'Crea un punto de restauracion y respalda el registro para volver atras.' }
        @{ Id = '02'; Title = 'Limpieza inicial'; Why = 'Borra temporales, papelera y caches para dar aire al disco.' }
        @{ Id = '03'; Title = 'CHKDSK'; Why = 'Comprueba el sistema de archivos del disco C: en busca de errores.' }
        @{ Id = '04'; Title = 'Optimizacion de disco'; Why = 'TRIM si es SSD o desfragmenta si es HDD, segun el tipo de disco.' }
        @{ Id = '05'; Title = 'DISM'; Why = 'Repara la imagen de componentes de Windows (el origen de SFC).' }
        @{ Id = '06'; Title = 'SFC y verificacion'; Why = 'Repara archivos de sistema y verifica el resultado tras DISM.' }
        @{ Id = '07'; Title = 'Reparar WMI'; Why = 'Comprueba y repara el repositorio WMI (su rotura causa fallos raros).' }
        @{ Id = '08'; Title = 'Apps de Store e Inicio'; Why = 'Re-registra las apps de la Store y repara el menu Inicio.' }
        @{ Id = '09'; Title = 'Busqueda y caches'; Why = 'Reconstruye el indice de Busqueda, cache de iconos/fuentes y el spooler.' }
        @{ Id = '10'; Title = 'Certificados y hora'; Why = 'Refresca certificados raiz y sincroniza la hora (arregla WU/Store/cert).' }
        @{ Id = '11'; Title = 'Red'; Why = 'Reinicia winsock, IP, DNS y proxy, y revisa el archivo hosts.' }
        @{ Id = '12'; Title = 'Directivas (GPO)'; Why = 'Reaplica las directivas de grupo para deshacer politicas mal aplicadas.' }
        @{ Id = '13'; Title = 'Windows Update'; Why = 'Repara Windows Update (servicios y cache). Respeta el bloqueo con /keepwu.' }
        @{ Id = '14'; Title = 'Winget'; Why = 'Repara winget y actualiza el gestor de paquetes.' }
        @{ Id = '15'; Title = 'Dispositivos'; Why = 'Lista drivers/dispositivos con error para que sepas que revisar.' }
        @{ Id = '16'; Title = 'Limpieza final e informe'; Why = 'Limpieza profunda, recalcula la salud y genera el informe HTML.' }
    )
}
