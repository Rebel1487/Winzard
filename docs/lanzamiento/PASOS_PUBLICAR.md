# ✅ Steps to publish Winzard on GitHub (step by step)

Everything you need is already in this repo. Follow the order.

---

## 1) Create the repository on GitHub

1. Go to **github.com → New repository**.
2. Name: **`Winzard`**. Visibility: **Public**.
3. ⚠️ **Do NOT check** "Add a README", ".gitignore" or "license" (yours are already in the repo; if GitHub creates its own, they clash with the first `push`).
4. **Create repository**.

---

## 2) Push the repo

Open PowerShell:
```powershell
cd C:\Users\alex\Desktop\github\Winzard
git remote add origin https://github.com/Rebel1487/Winzard.git
git push -u origin main
```
> If you already created the repo WITH a README/license, use: `git push -u origin main --force` (safe: it only overwrites the auto-generated README/license).

---

## 3) Configure the repo "About" (2 min, big impact)

On the repo page, top-right in **About** (⚙️):

- **Description:**
  > All-in-one installer, optimizer, cleaner and repair tool for Windows 10/11 (PowerShell + WPF). 360+ apps via winget, tweaks, debloat, 17-phase repair suite and custom ISO builder. Bilingual EN/ES, open source.
- **Website:** (optional) leave empty or link to the Release.
- **Topics** (they help people find you):
  `windows` `windows-11` `windows-10` `winget` `powershell` `debloat` `tweaks` `post-install` `wpf` `system-repair` `iso-creator` `windows-utility` `chris-titus` `automation` `spanish`

**Social preview** (the share thumbnail): **Settings → General → Social preview → Upload** and upload `docs/img/social-preview.png`.

---

## 4) Add the screenshots

- Take the **7 screenshots** following `docs/img/README.md`.
- Save them in `docs/img/` with the exact names (`wpi-hero.png`, `wpi-apps.png`, etc.).
- Push them:
```powershell
cd C:\Users\alex\Desktop\github\Winzard
git add docs/img
git commit -m "docs: screenshots"
git push
```
The READMEs will show them automatically.

---

## 5) Create Release v1.0.0 (with the downloadable ZIP)

**a) Build the ZIP** (exact bytes, already verified):
```powershell
cd C:\Users\alex\Desktop\github\Winzard
git archive --format=zip -o ..\Winzard-v1.0.0.zip HEAD
```
It lands in `C:\Users\alex\Desktop\github\Winzard-v1.0.0.zip`.
> *(One is already built there; regenerate it with the command above if you make more commits.)*

**b) Publish the Release:**
1. In the repo → **Releases → Draft a new release**.
2. **Choose a tag →** type `v1.0.0` → **Create new tag on publish**.
3. **Release title:** `Winzard v1.0.0`
4. **Description:** copy and paste the contents of **`RELEASE_NOTES_v1.0.0.md`** (repo root).
5. **Attach binaries:** drag **`Winzard-v1.0.0.zip`** into the *Assets* area.
6. Check **"Set as the latest release"** and **Publish release**.

---

## 6) Spread the word (optional but recommended)

- Ready-to-use texts in **`docs/lanzamiento/POSTS.md`** (Reddit, X, Dev.to — English and Spanish).
- Golden rule: **don't** post the same thing in 10 places at once. 1-2 relevant communities per day, with 1-2 screenshots, and reply to comments.
- Full premium presentation to copy: **`docs/PRESENTACION.md`**.

---

## 🔁 When you make more changes later

```powershell
cd C:\Users\alex\Desktop\github\Winzard
git add -A
git commit -m "describe the change"
git push
```
And if you ship a new version, repeat **step 5** with the new number (`v1.1.0`, etc.) and update `CHANGELOG.md`.

---

## 📂 Where everything is (in this repo)

| File | Purpose |
|---|---|
| `docs/PRESENTACION.md` | Full premium presentation (copy anywhere) |
| `RELEASE_NOTES_v1.0.0.md` | Text for the Releases tab |
| `docs/lanzamiento/POSTS.md` | Social posts (EN + ES) |
| `docs/lanzamiento/PASOS_PUBLICAR.md` | This guide |
| `docs/img/README.md` | Which screenshots to take and how |
| `docs/img/social-preview.png` | Social thumbnail (ready) |
| `README.md` / `README_ES.md` | Full manual (EN / ES) |
| `CHANGELOG.md` | Version history |
