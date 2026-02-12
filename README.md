# One-Click Toolkit
![One-Click Logo](https://as214354.network/one-click.png)
One-Click is a modular Linux infrastructure automation toolkit built for controlled server lifecycle management.
It provides structured, repeatable workflows for:

- OS reinstallation
- Disk migration
- Backup & restore
- Boot recovery
- Network repair
- Log inspection

Designed for hosting providers, infrastructure engineers, DevOps operators, and system administrators managing development and production Linux environments.


# How To Run
## Primary Mirror
```
curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /tmp/one-click.sh && \
bash /tmp/one-click.sh setup && \
rm -f /tmp/one-click.sh
```
## Backup Mirror
```
curl -fsSL https://as214354.network/one-click.sh -o /tmp/one-click.sh && \
bash /tmp/one-click.sh setup && \
rm -f /tmp/one-click.sh
```
On first execution, One-Click will:

- Install core required dependencies
- Initialize internal directories and cache structure
- Configure baseline environment checks
- Launch inside a managed tmux session

To reattach:
```
tmux attach
```
or
```
tmux attach -t one-click
```
To detach:
```
Ctrl+b d
```
# Usage

## Syntax

one-click [COMMAND]

---

## Command Reference

| Command      | Description |
|--------------|-------------|
| reinstall    | OS reinstallation module |
| backup       | Backup and restore tool using rsync with optional rclone support |
| migrator     | System migration tool supporting both rsync and dd modes |
| recovery     | Boot partition backup and recovery tool (BIOS, UEFI, GRUB) |
| repair       | Network repair module including configuration snapshot and restore |
| sys-info     | Display system information |
| system       | Display system information (alias of sys-info) |
| logs         | Interactive system log browser |
| log-browser  | Interactive system log browser (alias of logs) |
| cron         | Configure and manage cron jobs |
| help         | Show help and usage information |
| uninstall    | Remove One-Click and all associated files and configurations |

---

## Examples

**Run network repair:**
```
one-click repair
```
**Run backup tool:**
```
one-click backup
```
**Run OS reinstall module:**
```
one-click reinstall
```
**Run migration tool:**
```
one-click migrator
```
**Run recovery tool:**
```
one-click recovery
```
**View system information:**
```
one-click sys-info
```
**Open log browser:**
```
one-click logs
```
**Configure cron job:**
```
one-click cron
```
**Remove One-Click completely:**
```
one-click uninstall
```

# Core Capabilities

One-Click simplifies tedious and complex server tasks.
It is designed to operate safely in production environments with caching, fallback mirrors, and validation safeguards.

## OS Reinstall

- Network-based OS deployment
- Modular loader architecture
- Primary + fallback mirror support
- 24-hour module caching (TTL)
- Atomic temporary file replacement
- Automatic fallback to cached module if network fails

Designed for remote or recovery-only environments.

## Migration & Backup Modes

- dd block-level disk migration
- rsync incremental backups
- Profile-based configuration
- Dry-run support
- rclone integration
- Snapshot-aware workflows
- Non-interactive automation flags

Suitable for:

- Hardware replacement
- RAID rebuild workflows
- VPS migrations
- Provider transitions

## Boot & Recovery Tooling

- EFI remount automation
- GRUB reinstall assistance
- Boot partition backup
- Recovery structure validation
- Live-environment repair helpers

Designed for systems that fail to boot after disk or migration operations.

## Network Repair Module

- Network configuration snapshot
- Automated repair routines
- Fallback restoration logic
- Safe rollback model

Built for remote recovery scenarios where SSH access may be unstable.

## Log Management Console

- Interactive terminal-based log browser with:
- Arrow-key navigation
- Live preview pane
- Search filtering
- Priority highlighting
- Journalctl service browsing
- Safe deletion controls
- Cache + system log visibility

Built for fast diagnostics in headless environments.

# Dependency Model

Core dependencies installed during initial execution include:

- curl
- tmux
- core shell utilities
- epel-release
- rclone
- sgdisk
- sshpass
- psutil
- pv
- iostat
- whois
- fzf

Additional dependencies may be installed depending on distribution and module usage.

This staged model ensures minimal base footprint while maintaining full functionality.


## Architecture Highlights

- Modular remote-loaded components
- Primary + backup mirror awareness
- 24-hour intelligent cache TTL
- Network timeout safeguards
- Atomic file replacement strategy
- Graceful failure handling
- Bash-native portability

## Design Principles

- Production-safe defaults
- Fail predictably
- No silent corruption
- Minimal persistent footprint
- Modular by design
- Resilient in remote environments

One-Click is engineered for environments where:

- Servers are remote or headless
- Network stability is inconsistent
- Downtime must be minimized
- Recovery must be deterministic

## Requirements

- Bash 4+
- curl
- sudo or root access
Additional packages are installed automatically as required by specific modules.

## Disclaimer

One-Click is a modular toolkit.

Not all modules perform low-level system operations.

Certain tools — such as OS reinstallation, disk migration, or boot recovery — may perform operations including:

- Disk manipulation
- Bootloader modification
- Partition changes
- System reconfiguration

Other modules (such as log browsing or system information) are read-only or minimally invasive.

Risk level is therefore dependent on the module invoked.

Always:

- Understand the specific tool you are executing
- Review flags before confirming destructive actions
- Test workflows in staging before production use

Use responsibly in environments you control and understand.

