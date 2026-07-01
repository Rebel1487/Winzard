# Security Policy

> 🇪🇸 *¿Prefieres español?* La app es bilingüe; el manual está en [README_ES.md](README_ES.md).

## Winzard security philosophy

Winzard performs system operations (installing software, applying tweaks, repairing Windows, creating ISOs). That's why transparency is a core pillar:

- ✅ **No pirated software.** All apps are installed via **winget** from official Microsoft and developer manifests.
- ✅ **Open and auditable code.** All behavior lives in the repository's PowerShell scripts; you can read exactly what each action does.
- ✅ **Action logging.** Relevant operations leave logs.
- ✅ **Admin only when needed.** System operations explicitly request UAC elevation.
- ✅ **Reversible tweaks** whenever possible, with an optional restore point before applying.

## User best practices

1. **Download only from the official source** (this repository / its Releases).
2. **Review the code** if in doubt: it's readable PowerShell.
3. **Test in a virtual machine** before applying heavy changes to your main PC.
4. **Create a restore point** before applying tweaks or debloat (WPI offers this).
5. **Don't upload** ISOs, personal logs or internal reports to public repos.

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x | ✅ Yes |
| < 1.0 | ❌ No |

## Reporting a vulnerability

If you find a security issue, **do not post it in a public Issue**. Instead:

1. Open a private **Security Advisory** on GitHub (*Security* tab → *Report a vulnerability*), **or**
2. Contact the maintainer privately.

Include: description, reproduction steps, potential impact and, if possible, a proposed fix. We'll get back to you as soon as possible.
