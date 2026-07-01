# ✅ Pasos para publicar WPI Moderno en GitHub (paso a paso)

Todo lo que necesitas ya está en este repo. Sigue el orden.

---

## 1) Crear el repositorio en GitHub

1. Ve a **github.com → New repository**.
2. Nombre: **`WPI-Moderno`**. Visibilidad: **Public**.
3. ⚠️ **NO marques** "Add a README", ni ".gitignore", ni "license" (los tuyos ya están en el repo; si GitHub crea unos, chocan con el primer `push`).
4. **Create repository**.

---

## 2) Subir el repo (push)

Abre PowerShell:
```powershell
cd C:\Users\alex\Desktop\github\WPI-Moderno
git remote add origin https://github.com/Rebel1487/WPI-Moderno.git
git push -u origin main
```
> Si ya habías creado el repo CON README/license, usa: `git push -u origin main --force` (es seguro: solo sobrescribe el README/license autogenerados).

---

## 3) Configurar la ficha del repo (2 min, mucho impacto)

En la página del repo, arriba a la derecha en **About** (⚙️):

- **Description** (en inglés, para más alcance):
  > All-in-one installer, optimizer, cleaner and repair tool for Windows 10/11 (PowerShell + WPF). 360+ apps via winget, tweaks, debloat, 17-phase repair suite and custom ISO builder. Bilingual EN/ES, open source.
- **Website:** (opcional) déjalo vacío o pon el enlace a la Release.
- **Topics** (etiquetas, ayudan a que te encuentren):
  `windows` `windows-11` `windows-10` `winget` `powershell` `debloat` `tweaks` `post-install` `wpf` `system-repair` `iso-creator` `windows-utility` `chris-titus` `automation` `spanish`

**Social preview** (la miniatura al compartir): **Settings → General → Social preview → Upload** y sube `docs/img/social-preview.png`.

---

## 4) Añadir las capturas

- Haz las **7 capturas** siguiendo `docs/img/LEEME_CAPTURAS.md`.
- Guárdalas en `docs/img/` con los nombres exactos (`wpi-hero.png`, `wpi-apps.png`, etc.).
- Súbelas:
```powershell
cd C:\Users\alex\Desktop\github\WPI-Moderno
git add docs/img
git commit -m "docs: capturas"
git push
```
Los README las mostrarán solas.

---

## 5) Crear la Release v1.0.0 (con el ZIP descargable)

**a) Construye el ZIP** (bytes exactos, ya verificados):
```powershell
cd C:\Users\alex\Desktop\github\WPI-Moderno
git archive --format=zip -o ..\WPI-Moderno-v1.0.0.zip HEAD
```
Queda en `C:\Users\alex\Desktop\github\WPI-Moderno-v1.0.0.zip`.
> *(Ya te he dejado uno construido ahí; regenéralo con el comando de arriba si haces más commits.)*

**b) Publica la Release:**
1. En el repo → **Releases → Draft a new release** (o "Create a new release").
2. **Choose a tag →** escribe `v1.0.0` → **Create new tag on publish**.
3. **Release title:** `WPI Moderno v1.0.0`
4. **Description:** copia y pega el contenido de **`docs/lanzamiento/RELEASE_v1.0.0.md`**.
5. **Attach binaries:** arrastra **`WPI-Moderno-v1.0.0.zip`** a la zona de *Assets*.
6. Marca **"Set as the latest release"** y **Publish release**.

---

## 6) Difundir (opcional pero recomendado)

- Textos listos en **`docs/lanzamiento/POSTS.md`** (Reddit, X, Dev.to, en inglés y español).
- Regla de oro: **no** el mismo post en 10 sitios a la vez. 1-2 comunidades relevantes por día, con 1-2 capturas, y responde a los comentarios.
- Presentación premium completa para copiar: **`docs/PRESENTACION.md`**.

---

## 🔁 Cuando hagas más cambios más adelante

```powershell
cd C:\Users\alex\Desktop\github\WPI-Moderno
git add -A
git commit -m "describe el cambio"
git push
```
Y si sacas una versión nueva, repite el **paso 5** con el nuevo número (`v1.1.0`, etc.) y actualiza `CHANGELOG.md`.

---

## 📂 Dónde está cada cosa (en este repo)

| Archivo | Para qué |
|---|---|
| `docs/PRESENTACION.md` | Presentación premium completa (para copiar donde quieras) |
| `docs/lanzamiento/RELEASE_v1.0.0.md` | Texto de la pestaña Releases |
| `docs/lanzamiento/POSTS.md` | Posts de redes (EN + ES) |
| `docs/lanzamiento/PASOS_PUBLICAR.md` | Esta guía |
| `docs/img/LEEME_CAPTURAS.md` | Qué capturas hacer y cómo |
| `docs/img/social-preview.png` | Miniatura social (ya lista) |
| `README.md` / `README_EN.md` | Manual completo (ES / EN) |
| `CHANGELOG.md` | Historial de versiones |
