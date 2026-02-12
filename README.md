# One-Click Toolkit

One-Click is a modular infrastructure automation toolkit designed for rapid OS reinstallation, migration, backup, and recovery operations on Linux servers.

Built for operators, administrators, hosting providers, and infrastructure engineers who need fast, repeatable, and reliable server lifecycle management.

---

## How To Run
```
curl -fsSL https://as214354.network/one-click.sh -o /tmp/one-click.sh; bash /tmp/one-click.sh setup && rm -f /tmp/one-click.sh
```
or
```
curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /tmp/one-click.sh; bash /tmp/one-click.sh setup && rm -f /tmp/one-click.sh
```
---
## Core Purpose

One-Click simplifies tedious and complex server tasks such as:

- OS reinstallation
- Disk migrations
- Backup & restore workflows
- Disaster recovery preparation
- Live environment repair
- Log inspection & diagnostics

It is designed to operate safely in production environments with caching, fallback mirrors, and validation safeguards.

---
## Key Features

### OS Reinstall
- Remote script loading with:
  - Primary + backup mirror support
  - 24-hour cache TTL
  - Safe temporary file replacement
- Automatic fallback to cached module if network fails
- Modular loading architecture
- Network OS Reinstallation

---

### Migration & Backup Modes
- `dd` based block migration
- `rsync` incremental backups
- Profile-based configuration support
- Dry-run support
- Snapshot-friendly workflows

---

### Recovery Tooling
- Boot repair helper
- EFI re-mount automation
- GRUB reinstall assistance
- Emergency live-environment helpers

---

### Log Management Console
Interactive TUI log system:

- Arrow key navigation
- Live preview window
- Search filtering
- Highlighted priority logs
- Journalctl service browser
- Safe delete support
- Cache and system log visibility

---

### Mirror & Cache Awareness

- Primary + backup URL support
- 24h TTL cache logic
- Network timeout safeguards
- Fallback to last known working module
- Designed for unreliable or remote environments

---

## Design Philosophy

- Production-safe by default
- Fail gracefully
- No silent corruption
- Minimal external dependencies
- Clean modular structure
- Bash-native portability

One-Click is built for environments where:

- Servers may be remote
- Network may be unreliable
- Downtime must be minimized
- Recovery must be predictable

---

## 📦 Requirements

- Bash 4+
- curl
- sudo or root access
---
## Disclaimer

This tool performs low-level system operations including disk manipulation and OS reinstallation. Use only in environments you control and understand.

Always test in staging before production use.

