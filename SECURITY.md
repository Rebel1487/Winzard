# Política de Seguridad · Security Policy

> 🇪🇸 Español · 🇬🇧 [English below](#-english)

---

## 🇪🇸 Español

### Filosofía de seguridad de WPI Moderno

WPI Moderno realiza operaciones de sistema (instalar software, aplicar tweaks, reparar Windows, crear ISOs). Por eso la transparencia es un pilar del proyecto:

- ✅ **Sin software pirata.** Todas las apps se instalan con **winget** desde manifiestos oficiales de Microsoft y de los desarrolladores.
- ✅ **Código abierto y auditable.** Todo el comportamiento está en los scripts PowerShell del repositorio; puedes leer exactamente qué hace cada acción.
- ✅ **Registro de acciones.** Las operaciones relevantes dejan logs.
- ✅ **Administrador solo cuando hace falta.** Las operaciones de sistema piden elevación UAC de forma explícita.
- ✅ **Tweaks reversibles** siempre que es posible, con punto de restauración opcional antes de aplicar.

### Buenas prácticas para el usuario

1. **Descarga solo desde la fuente oficial** (este repositorio / sus Releases).
2. **Revisa el código** si tienes dudas: es PowerShell legible.
3. **Prueba en una máquina virtual** antes de aplicar cambios fuertes en tu equipo principal.
4. **Crea un punto de restauración** antes de aplicar tweaks o debloat (WPI lo ofrece).
5. **No subas** ISOs, logs personales ni informes internos a repositorios públicos.

### Versiones soportadas

| Versión | Soporte |
|---|---|
| 1.0.x | ✅ Sí |
| < 1.0 | ❌ No |

### Reportar una vulnerabilidad

Si encuentras un problema de seguridad **no lo publiques en un Issue público**. En su lugar:

1. Abre un **Security Advisory** privado en GitHub (pestaña *Security* → *Report a vulnerability*), **o**
2. Contacta de forma privada con el mantenedor.

Incluye: descripción, pasos para reproducir, impacto potencial y, si puedes, una propuesta de solución. Te responderemos lo antes posible.

---

## 🇬🇧 English

### WPI Moderno security philosophy

WPI Moderno performs system operations (installing software, applying tweaks, repairing Windows, creating ISOs). That's why transparency is a core pillar:

- ✅ **No pirated software.** All apps are installed via **winget** from official Microsoft and developer manifests.
- ✅ **Open and auditable code.** All behavior lives in the repository's PowerShell scripts; you can read exactly what each action does.
- ✅ **Action logging.** Relevant operations leave logs.
- ✅ **Admin only when needed.** System operations explicitly request UAC elevation.
- ✅ **Reversible tweaks** whenever possible, with an optional restore point before applying.

### User best practices

1. **Download only from the official source** (this repository / its Releases).
2. **Review the code** if in doubt: it's readable PowerShell.
3. **Test in a virtual machine** before applying heavy changes to your main PC.
4. **Create a restore point** before applying tweaks or debloat (WPI offers this).
5. **Don't upload** ISOs, personal logs or internal reports to public repos.

### Supported versions

| Version | Supported |
|---|---|
| 1.0.x | ✅ Yes |
| < 1.0 | ❌ No |

### Reporting a vulnerability

If you find a security issue, **do not post it in a public Issue**. Instead:

1. Open a private **Security Advisory** on GitHub (*Security* tab → *Report a vulnerability*), **or**
2. Contact the maintainer privately.

Include: description, reproduction steps, potential impact and, if possible, a proposed fix. We'll get back to you as soon as possible.
