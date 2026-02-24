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

## Supported Platforms

One‑Click supports most mainstream Linux distributions, including Debian,
Ubuntu, CentOS, Fedora, Rocky, AlmaLinux, openSUSE, Arch, and others.

> Note: BSD systems are not supported at this time, and Alpine Linux may have
> limited compatibility

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
| bench        | One-Click Bench (OCB) performance benchmark suite |
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
**Run performance benchmark (OCB):**
```
one-click bench
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

## One-Click Bench (OCB)

One-Click Bench (OCB) is the integrated performance benchmarking module
designed to evaluate infrastructure quality and detect bottlenecks.

It provides a structured, repeatable benchmarking workflow suitable for:

- VPS validation
- Dedicated server verification
- Cloud instance comparison
- Pre-deployment testing
- Post-migration performance checks

### Benchmark Coverage

OCB evaluates multiple subsystems:

- **CPU performance** – single and multi-threaded computational workloads  
- **Memory performance** – sequential read/write bandwidth tests  
- **Disk performance** – sequential and random I/O throughput and latency  
- **Network latency** – multi-target latency measurement with automatic sorting  
- **System profiling** – virtualization detection, CPU model, kernel, architecture  

### Network Test Logic

- All test targets are ping-tested first  
- Targets are sorted by lowest round-trip latency  
- Bandwidth or extended tests run in ranked order  
- Ensures consistency and fair comparison across environments  

### Design Characteristics

- Non-destructive and safe for production systems  
- Automatic dependency handling  
- Structured table output with optional color scoring  
- Runs inside managed tmux session to prevent interruption  
- No persistent system changes  

OCB is designed for engineers who need fast, reproducible performance metrics
without installing heavy benchmarking suites manually.

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

## Security Notice

One-Click uses standard, widely available system binaries and does not build,
compile, or embed third-party executable code.

Core operations rely on tools such as:

- curl
- tmux
- rsync
- rclone
- dd
- sgdisk
- standard GNU/Linux utilities

No custom binaries are downloaded or compiled during normal operation.

### Remote Script Delivery

The initial bootstrap script is retrieved over HTTPS from a public repository
or mirror. While HTTPS provides transport security, fetching and executing
remote scripts always carries inherent risk.

Users are strongly encouraged to:

- Review the script before execution
- Verify repository integrity
- Pin to a specific commit when deploying in production
- Maintain internal mirrors for controlled environments
- Restrict execution to trusted networks

### Operational Scope

Certain modules (e.g., reinstall, migration, recovery) perform privileged
operations including disk modification and bootloader changes.

Security posture depends on:

- Proper access control
- Use of SSH keys instead of passwords
- Limiting root access
- Reviewing destructive confirmations before execution

One-Click does not include telemetry, external reporting, or hidden background
services.

All actions are explicit and user-initiated.

## Requirements

- Bash 4+
- curl
- sudo or root access
Additional packages are installed automatically as required by specific modules.

## Acknowledgements

Portions of design inspiration, benchmarking logic, and implementation
patterns were influenced by the following open-source projects:

- [YABS – Yet Another Bench Script](https://github.com/masonr/yet-another-bench-script)  
  Contributed inspiration for structured benchmarking workflows,
  network test sequencing, and formatted performance output.

- [reinstall by bin456789](https://github.com/bin456789/reinstall)  
  Influenced aspects of OS deployment methodology and reinstall logic.

One-Click does may embed these projects directly or incorporates concepts,
ideas, and selected implementation approaches adapted to fit its modular
architecture.

Credit and appreciation are extended to the maintainers and contributors of
these projects for their work in advancing open infrastructure tooling.

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

