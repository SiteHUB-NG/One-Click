# One-Click Toolkit
![One-Click Logo](https://as214354.network/one-click.png)
# One-Click — Linux Infrastructure Automation Toolkit

**One-Click** is your personal Linux system administration companion. A modular infrastructure automation toolkit designed for **controlled, repeatable server lifecycle management**.

It provides a structured approach to managing Linux environments, eliminating manual repetition while maintaining full control and transparency.

---

## Features

One-Click delivers streamlined workflows for essential system administration tasks:

- **OS Reinstallation**
- **Disk Migration**
- **Backup & Restore**
- **Boot Recovery**
- **Network Repair**
- **Log Inspection**
- **Firewall Configuration**
- **System Benchmarking**
- **Secure System State Management**
- **Web Hosting Deployment**
- **Fully Isolated Web Hosting Environments (vhosts)**

## Purpose

One-Click is built to:

- Simplify repetitive administrative tasks  
- Standardize infrastructure operations  
- Provide consistent, predictable system behavior  
- Enable rapid deployment and recovery workflows  

Whether you're managing a single server or multiple environments, One-Click ensures your operations remain **reliable, reproducible, and efficient**.

## Who is it for?

- **Enthusiasts** — automate complex tasks without deep system knowledge  
- **Advanced users** — accelerate workflows and maintain clean infrastructure  
- **Production environments** — enforce consistency and reduce human error  
- **Development setups** — quickly spin up and manage isolated environments  

## Supported Platforms

One-Click supports most mainstream Linux distributions, including:

- Debian  
- Ubuntu  
- CentOS  
- Fedora  
- Rocky Linux  
- AlmaLinux  
- openSUSE  
- Arch Linux  

> **Note:** BSD and Alpine Linux are not supported at this time.

## Design Philosophy

- **Modular** — use only what you need  
- **Deterministic** — predictable outcomes every time  
- **Isolated** — per-service and per-site separation  
- **Transparent** — no hidden magic, full control remains with the user  

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
| rule-engine  | Human-Readable Firewall Management |
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
**Run Performance Benchmark**
```
one-click-bench
```
**Configure iptables with words**
```
one-click engine 'open ssh and drop http,https and mask in nat table'
```

# Core Capabilities

One-Click simplifies tedious and complex server tasks.
It is designed to operate safely in production environments with caching, fallback mirrors, and validation safeguards.

## WordPress Automation Module

The One-Click WordPress module is a **full-stack site provisioning engine**, not just an installer. It automates the creation of complete, isolated web application environments per domain, including web server configuration, database provisioning, PHP runtime isolation, SSL management, and backup lifecycle handling.

Each WordPress deployment is treated as a **standalone system service** with dedicated resources and strict isolation boundaries.

### Key Capabilities
- Fully automated WordPress deployment via WP-CLI
- Per-site isolation using Linux system users and PHP-FPM pools
- Independent webserver virtual host generation (Nginx or Apache)
- Automatic database creation with unique credentials per site
- Systemd-based CPU and memory isolation per domain
- SSL provisioning and renewal via Let's Encrypt (Certbot)
- Structured backup system per domain
- Deterministic filesystem layout under /etc/one-click
- Optional caching integration (e.g., Redis plugin support)

### Commands

| Command                          | Description |
|----------------------------------|-------------|
| `one-click --wp-create`          | Deploy a new WordPress instance. Prompts for domain, admin credentials, database, and optional Redis configuration. Handles file setup, database creation, webserver configuration, and baseline hardening. |
| `one-click --wp-ssl`             | Install and configure SSL via Let's Encrypt for an existing WordPress and static sites. Automatically updates WordPress home and site URLs to use `https`. |
| `one-click --wp-backup`          | Local and remote backup and restore for Wordpress sites. Profiles allow for multi-target remote backups |`. |

### Usage Examples

**Create a new WordPress site:**
```
one-click --wp-create
```
**Wordpress Management**
```
one-click --wp
one-click --wp-admin
```
**Install SSL for an existing WordPress site:**
```
one-click --ssl
```

### System Layout
Each deployment follows a strict structure:
```
/etc/one-click/wordpress/<domain>/www
```
Backups:
```
/etc/one-click/wordpress/backups/<domain>
```
SSL certificates:
```
/etc/letsencrypt/live/<domain>
```
### Notes

- Each WordPress site runs under its own system user and PHP-FPM pool
- Resource usage is controlled via systemd slices per domain
- DNS A records for both root and www must point to the server before SSL issuance
- SSL provisioning depends on successful domain validation and port 80 availability
- Failures in SSL do not block site provisioning; HTTP deployment continues safely
- All credentials (database and admin) are generated or validated with enforced complexity rules

## OS Reinstall

The One-Click OS Reinstall module is a network-based server provisioning and recovery system that wraps an external reinstall engine (reinstall.sh) with a guided, fault-tolerant, and interactive selection layer.

It is designed for bare-metal recovery, VPS redeployment, and remote OS imaging, with built-in resilience for unstable network conditions.

Unlike traditional reinstall tools, this module adds:

- Mirror redundancy
- Interactive OS selection
- Secure credential handling
- Optional SSH key provisioning
- Structured OS/image mapping
- Safe confirmation flow before destructive actions

Designed for remote or recovery-only environments.

### Image Mapping System

OS options are dynamically parsed from the upstream reinstall engine and normalized into a structured selection list.

Supported OS families include:

Debian / Ubuntu
CentOS / Rocky / AlmaLinux / RHEL
Fedora / OpenSUSE / Alpine
Windows Server variants
Other netboot-compatible images

Each OS may include multiple version mappings resolved at runtime.

## Migration & Backup Modes

One-Click Migrator enables safe, automated, and reproducible server migrations across physical machines, virtual machines, and cloud environments.

It supports both full-disk cloning and incremental file synchronization, with built-in recovery tooling and automated post-migration repair workflows.

The tool is designed for reliability in production environments where downtime, consistency, and recoverability are critical.

- Block-level disk cloning using dd
- Incremental file synchronization via rsync
- Profile-driven configuration management
- Safe execution with dry-run validation
- Cloud storage support via rclone
- Snapshot-aware migration workflows
- Fully automated non-interactive mode

### Core Features
#### Migration Modes:

##### Block Level Cloning (dd)

- Bit-for-bit disk replication
- Preserves bootloader, partitions, and filesystem structure
- Suitable for full system duplication

##### File Level Synchronization (rsync)

- Incremental, bandwidth-efficient transfers
- Supports resume and partial sync
- Ideal for live or staged migrations

### Backup & Safety Mechanisms

- Dry-run mode for validation before execution
- Snapshot-aware workflows (where supported)
- Pre-migration system state capture
- Automatic backup of critical configuration files
- Service state tracking and restoration

### Recovery System

- Embedded recovery environment generation
- Custom initramfs-based rescue mode
- Automated GRUB repair utilities
- Post-migration filesystem repair scripts
- Emergency SSH access via Dropbear in recovery mode

### Designed For:

- Hardware replacement
- RAID rebuild workflows
- VPS migrations
- Provider transitions

### Boot & Recovery Tooling

- EFI remount automation
- GRUB reinstall assistance
- Boot partition backup
- Recovery structure validation
- Live-environment repair helpers

Designed for systems that **fail to boot after disk or migration operations**.

## Network Repair Module

A resilient network recovery utility designed for unstable or remote environments.

### Core Features

- **Configuration Snapshots** – Capture the current network state for safe recovery points
- **Automated Repair Routines** – Attempt intelligent fixes for common connectivity failures
- **Fallback Restoration Logic** – Reapply known working configurations when issues persist
- **Safe Rollback Model** – Restore previous states without risking further disruption

### Purpose

Built specifically for remote systems where SSH access may be unreliable or degraded.

When prior snapshots exist, the module can reliably restore a known-good network state.
Without them, it switches to adaptive repair logic—making calculated attempts to recover connectivity.

### Notice

This tool improves recovery chances but does **not guarantee** a successful fix in all scenarios.

## RuleEngine – Human-Readable Firewall Management

`rule-engine` is a **human-readable firewall rule parser and executor** integrated into the One-Click toolkit. It allows administrators to manage firewall rules using **intuitive, plain-language commands**, which are automatically translated into the appropriate backend commands for `iptables`, `ip6tables` and `nftables`.

### Firewall Backup, Restore, and Delete

One-Click supports **full firewall configuration management** through the `rule-engine` module. Users can **backup**, **restore**, and **delete** firewall rules safely, with interactive tables and confirmations.  

The commands can be triggered using natural language variants:

- **Backup / Save / Retain**:  
  `(backup|save|retain|copy|export|dump|snapshot)([[:space:]]+(firewall|config|configuration|file|rules|ruleset|policy))?`
- **Restore / Reinstate / Revive**:  
  `(restore|revive|recreate|regenerate|repair|import|reinstate)([[:space:]]+(firewall|config|configuration|file|rules|ruleset|policy))?`
- **Delete / Remove**:  
  `(delete|remove|purge)[[:space:]]+(firewall|config|configuration|file|rules|ruleset|policy)`

These commands automatically create and manage backups in: 
`/etc/one-click/rule-engine/`

### Backup Firewall

Backups are timestamped and stored in `/etc/one-click/rule-engine/`.  

**Examples:**

```
one-click rule-engine "backup"
one-click rule-engine "save firewall"
one-click rule-engine "retain ruleset"
```
**What happens:**

- Creates the backup directory if it doesn’t exist.
- Detects the active firewall backend (iptables, nftables, ufw, firewalld).
- Saves the current configuration to a timestamped file.
- Permissions set to 600 to restrict access.

Sample Output:
`[INFO]: Firewall configuration saved to /etc/one-click/rule-engine/iptables-2026-02-25-144512.backup`

### Restore Firewall

Users can restore from one or more existing backups.
If multiple backups exist, a table is displayed for selection.

Examples:
```
one-click rule-engine "restore"
one-click rule-engine "reinstate firewall"
one-click rule-engine "import ruleset"
```

### Delete Firewall Backup

Old backups can be safely removed using an interactive selection table.

Examples:
```
one-click rule-engine "delete firewall"
one-click rule-engine "remove configuration"
one-click rule-engine "purge firewall ruleset"
```

### Key Capabilities

- Human-readable rule parsing (`open`, `close`, `allow`, `block`, `drop`, `delete`)  
- TCP, UDP, ICMP, and multiport support  
- Source and destination IP filtering with CIDR notation  
- Connection state filters (NEW, ESTABLISHED)  
- Service name to port mapping (e.g., `ssh` → 22)  
- Automatic detection of active firewall backend  
- Dry-run mode for safe testing  
- Interactive preview and confirmation before applying rules  
- Logs applied rules to `/var/log/one-click/ruleengine.log`  

### Usage Examples

**Open SSH port**
```
one-click rule-engine "enable ssh"
one-click rule-engine "allow ssh"
```
**Block MySQL port**
```
one-click engine "close 3306"
```
**Enable ICMP (ping)**
```
one-click rule-engine "enable icmp"
```
**Delete the 3rd rule in the INPUT chain**
```
one-click firewall "delete line 3"
```
**Using raw input**
```
one-click rule-engine "raw: iptables -I INPUT -p tcp -m tcp-comment --dport 443 -j ACCEPT"
```
**Preview rules without applying**
```
one-click engine --dry-run "open https"
```

  **Command:** `one-click rule-engine`  

**Subcommands:**

| Subcommand Syntax                        | Description |
|-----------------------------------------|-------------|
| `(show\|list)`                           | List rule tables by including an arguement such as show nat. Default will show defaul table. Can also be used to show alias mapping with alias as the arg. |
| `show mangle`                            | Show mangle table |
| `show alias `                            | Show alias mapping |
| `show <table>`                           | Show selected table |
| `(backup\|save\|retain)`                 | Backup rules |
| `(restore\|reinstate\|import) <arg>`     | Restore snapshot rules |
| `(remember\|include) <alias> <ip/s>`     | Alias mapping for batch processing. Multiple IP's must be delimited with a space |
| `(delete\|remove\|purge) (firewall\|config\|rules\|alias)` | Delete a saved backup, firewall table and alias |
| `raw: <COMMAND>` | Directly input raw commands|

**Usage Examples:**

Open SSH port:

```
one-click engine "allow ssh"
```
---

## Operation Details

1. Detects the active firewall backend automatically.
2. Parses human-readable rules into validated firewall commands.
3. Maps service names to standard ports automatically.
4. Validates IP addresses, ports, and connection states.
5. Displays a preview and requests confirmation before applying (unless in dry-run mode).
6. Applies rules safely and logs actions.

## Raw Entry Mode

RuleEngine supports a **`raw:` entry mode**, allowing advanced users to inject full native `iptables` commands directly into the execution pipeline.

Raw mode bypasses natural-language parsing and sends the command straight into the normalization and execution layer.

### Syntax

raw: <full iptables command>

- The `raw:` prefix is required.
- Everything after `raw:` is treated as a direct `iptables` command.
- Flags are automatically normalized (e.g., `-a` → `-A`).
- Jump targets such as `ACCEPT` and `DROP` are automatically capitalized.
- The `-j` flag remains lowercase (as required by `iptables`).

### Example Usage

Input:
```
raw: iptables -a INPUT -p tcp --dport 80 -j accept
```
After normalization:

```
iptables -A INPUT -P TCP --DPORT 80 -j ACCEPT
```
### Chaining Commands

Raw commands can be chained together as well as with human language parsed input. However, spacing rules are strict to prevent accidental fallback into human-language parsing when using `raw:`.
Chaining can be used with any service. Ports will be mapped without further input.

![One-Click Logo](https://as214354.network/one-click-rule-engine.png)

![One-Click Logo](https://as214354.network/oc-rule-engine.png)

#### Using Comma `,` Delimiter

When chaining with a comma:

The next raw: must begin immediately.

No leading space before raw:.

Correct:
```
raw: iptables -A INPUT -p tcp --dport 22 -j ACCEPT,raw: iptables -L
```
Incorrect
```
raw: iptables -A INPUT -p tcp --dport 22 -j ACCEPT, raw: iptables -L
```
(Leading space before raw: may trigger natural-language parsing.)

#### Using `and` Delimiter

When chaining with and:

There must be exactly one space after and

There must be exactly one space before raw:

Correct:
```
raw: iptables -A INPUT -p tcp --dport 22 -j ACCEPT and raw: iptables -L
```
Incorrect:
```
raw: iptables -A INPUT -p tcp --dport 22 -j ACCEPT and  raw: iptables -L
raw: iptables -A INPUT -p tcp --dport 22 -j ACCEPT andraw: iptables -L
```
Improper spacing may cause the parser to interpret the command as natural language instead of raw mode.

Use `raw:` when you need full control over advanced match extensions.

### Security Considerations

- Root privileges are required to modify firewall rules.
- Always review generated commands, especially when opening sensitive ports (22, 80, 443, 3389).
- Use --dry-run for safe testing before applying rules.
- Back up existing firewall rules to prevent accidental lockout.

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

**Command:** `one-click logs` or `one-click log-browser`  

**Subcommands:**

| Subcommand     | Description                  |
|----------------|-----------------------------|
| `Ctrl+E`       | Go back to previous menu     |
| `Ctrl+F`       | Delete selected log file     |
| `Ctrl+A`       | Vacuum all log files         |

---

# Dependency Model

Core dependencies installed during initial execution include:

- core shell utilities
- curl
- epel-release
- fzf
- iostat
- iptables
- psutil
- pv
- rclone
- sgdisk
- sshpass
- tmux
- whois

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
compile, or embed third-party executable code outside of Geekbench.

Core operations rely on tools such as:

- curl
- tmux
- rsync
- rclone
- dd
- sgdisk
- standard GNU/Linux utilities

No custom binaries are downloaded or compiled during normal operation outside of Geekbench.

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

