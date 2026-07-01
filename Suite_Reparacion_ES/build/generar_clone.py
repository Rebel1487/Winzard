#!/usr/bin/env python3
# Clon determinista de build/generar.ps1 (Tareas 2.1/2.2/11.1).
# Replica EXACTAMENTE el ensamblado para que, en Windows, `generar.ps1 -Check`
# devuelva 0 sobre los .bat producidos aqui.
import base64, hashlib, json, re, os, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC  = os.path.join(ROOT, 'src')
BUILD= os.path.join(ROOT, 'build')
LOCK = os.path.join(BUILD, 'manifest.lock.json')
HLP_LEN = 200

PHASE_NAMES = {
 '00':'Fase_00_Diagnostico_y_triage.bat','01':'Fase_01_Punto_de_restauracion.bat',
 '02':'Fase_02_Limpieza_inicial.bat','03':'Fase_03_CHKDSK.bat',
 '04':'Fase_04_Optimizacion_de_disco.bat','05':'Fase_05_DISM.bat',
 '06':'Fase_06_SFC_y_verificacion.bat','07':'Fase_07_Reparar_WMI.bat',
 '08':'Fase_08_Apps_de_Store_e_Inicio.bat','09':'Fase_09_Busqueda_y_caches.bat',
 '10':'Fase_10_Certificados_y_hora.bat','11':'Fase_11_Red.bat',
 '12':'Fase_12_Directivas_GPO.bat','13':'Fase_13_Windows_Update.bat',
 '14':'Fase_14_Winget.bat','15':'Fase_15_Dispositivos.bat',
 '16':'Fase_16_Limpieza_final_e_informe.bat'}

SRC_RE = re.compile(r'^\s*::SRC')

def source_body(path):
    with open(path, 'r', encoding='utf-8', newline='') as f:
        data = f.read()
    return [ln for ln in data.splitlines() if not SRC_RE.match(ln)]

def build_hlp(helper_path, line_len=HLP_LEN):
    with open(helper_path, 'rb') as f:
        b = f.read()
    b64 = base64.b64encode(b).decode('ascii')
    return ['HLP:' + b64[i:i+line_len] for i in range(0, len(b64), line_len)], b

def assemble(header, body, lib, hlp):
    alll = list(header) + list(body) + list(lib) + list(hlp)
    return '\r\n'.join(alll) + '\r\n'

def write_bat(path, text):
    # ASCII como en PS (no-ASCII -> '?'); aqui todo debe ser ASCII ya.
    data = text.encode('ascii', 'replace')
    with open(path, 'wb') as f:
        f.write(data)

def sha_hex_bytes(b):
    return hashlib.sha256(b).hexdigest()

def sha_of_lines(lines):
    return sha_hex_bytes('\n'.join(lines).encode('utf-8'))

def embedded_lib_block(lines):
    lib_start = hlp_start = -1
    for i, l in enumerate(lines):
        if lib_start < 0 and re.match(r'^:wpi_initcolors\s*$', l):
            lib_start = i
        if l.startswith('HLP:'):
            hlp_start = i; break
    if lib_start < 0 or hlp_start < 0 or lib_start >= hlp_start:
        return None
    return lines[lib_start:hlp_start]

def embedded_hlp_block(lines):
    hlp = [l for l in lines if l.startswith('HLP:')]
    return hlp or None

def manifest_version():
    try:
        txt = open(os.path.join(SRC,'manifest.psd1'),encoding='utf-8').read()
        m = re.search(r"WPI_VERSION\s*=\s*'([^']+)'", txt)
        return m.group(1) if m else '0.0'
    except Exception:
        return '0.0'

def targets():
    t = [('Suite_Reparacion_TodoEnUno.bat', os.path.join(SRC,'orquestador.body.cmd'))]
    for n in range(17):
        nn = f'{n:02d}'
        t.append((PHASE_NAMES[nn], os.path.join(SRC, f'fase_{nn}.body.cmd')))
    return t

def main(out_dirs):
    header = source_body(os.path.join(SRC,'header.cmd'))
    lib    = source_body(os.path.join(SRC,'lib_wpi.cmd'))
    hlp, brain_bytes = build_hlp(os.path.join(SRC,'suite_helper.ps1'))

    combined = lib + hlp
    canon_lib = embedded_lib_block(combined)
    canon_hlp = embedded_hlp_block(combined)
    assert canon_lib is not None, "no :wpi_initcolors en libreria canonica"
    assert canon_hlp is not None, "no bloque HLP canonico"
    canon_lib_hash = sha_of_lines(canon_lib)
    canon_hlp_hash = sha_of_lines(canon_hlp)
    canon_brain_hash = sha_hex_bytes(brain_bytes)
    ver = manifest_version()

    file_entries = []
    for name, bodypath in targets():
        body = source_body(bodypath)
        text = assemble(header, body, lib, hlp)
        for d in out_dirs:
            os.makedirs(d, exist_ok=True)
            write_bat(os.path.join(d, name), text)
        # re-extraer de lo generado (igual que el PS)
        glines = text.replace('\r\n','\n').split('\n')
        if glines and glines[-1]=='' : glines=glines[:-1]
        lb = embedded_lib_block(glines); hb = embedded_hlp_block(glines)
        file_entries.append({'name':name,'librarySha256':sha_of_lines(lb),'hlpBlockSha256':sha_of_lines(hb)})

    lock = {
        'version': ver,
        'generatedAtUtc': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'hlpLineLength': HLP_LEN,
        'canonical': {
            'librarySha256': canon_lib_hash,
            'brainSha256': canon_brain_hash,
            'hlpBlockSha256': canon_hlp_hash,
        },
        'files': file_entries,
    }
    with open(LOCK,'w',encoding='utf-8') as f:
        json.dump(lock, f, indent=2, ensure_ascii=False)
        f.write('\n')

    print(f"Generados {len(file_entries)} .bat en: {', '.join(out_dirs)}")
    print(f"  version={ver} hlpLineLength={HLP_LEN}")
    print(f"  libreria SHA-256: {canon_lib_hash}")
    print(f"  cerebro  SHA-256: {canon_brain_hash}")
    print(f"  HLP      SHA-256: {canon_hlp_hash}")
    # comprobar uniformidad
    libs={e['librarySha256'] for e in file_entries}
    hlps={e['hlpBlockSha256'] for e in file_entries}
    print(f"  libreria uniforme en los 18: {'SI' if libs=={canon_lib_hash} else 'NO'}")
    print(f"  cerebro  uniforme en los 18: {'SI' if hlps=={canon_hlp_hash} else 'NO'}")

if __name__ == '__main__':
    main([ROOT, os.path.join(BUILD,'out')])
