# One-Click Toolkit
![One-Click Logo](https://as214354.network/one-click.png)
# One-Click — Linux Infrastructure Automation Toolkit

One-Click is an advanced operational console engineered for power users, developers, and sysadmins who demand maximum control with zero infrastructure bloat. Built on a strict **security-first-by-design** architecture, One-Click completely redefines server management by replacing vulnerable, resource-heavy web UIs with a lean, terminal-driven automation matrix.

By abstracting complex Linux primitives into predictable, guided workflows, One-Click eliminates the syntax burden of server administration while maintaining total architectural transparency.

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

## Core Architectural Pillars

* **Modular Infrastructure Automation** Spin up completely isolated environments on demand. From localized, single-tenant Node.js runtimes utilizing private binary paths to isolated database pools, your server stack remains clean, predictable, and conflict-free.
* **Workflow-Driven Orchestration** Complex deployments—like installing web servers, provisioning directory-traversal-proof codebases, or cloning Git repositories—are condensed into seamless, structured execution chains.
* **Context-Aware Deployments** One-Click inherently understands your server topology. It dynamically configures reverse proxy boundaries (Nginx or Apache), auto-scans for vacant network loops, and maps filesystems safely based on active domain environments.
* **Semantic Firewall & Security Orchestration** Security isn't an afterthought; it is baked into the transport layer. Features an aggressive, automated, out-of-band credential injection wrapper, loopback-restricted bindings (`127.0.0.1`), and single-use, time-bound authentication tokens that shred themselves instantly upon validation.


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
## The Power User Advantage

| Feature | Traditional GUI Panels (e.g., cPanel) | One-Click Engine |
| :--- | :--- | :--- |
| **Attack Surface** | **High** (Public login portals exposed to brute-force botnets) | **Near Zero** (No permanent web login interface exists) |
| **System Footprint** | **Heavy** (Persistent background daemons hoard RAM/CPU) | **Zero-Overhead** (Awakens strictly on-demand per intent) |
| **Authentication** | **Static** (Username/Password combinations) | **Ephemeral** (Single-use tokens generated via local shell) |
| **Environment State** | **Shared** (Global binaries risk dependency hell) | **Sandboxed** (Private binary scopes per application path) |

### Zero-Knowledge Authentication
There is no permanent admin login page for hackers to target. Accessing internal modules like One-Click DB Manager requires a secure, short-lived shell token generated from the local terminal.

### Immutable Cleanliness
Because every application layer (PHP pools, Node engines, configuration states) is self-contained and path-mapped, deleting a site or environment is truly immutable. Run a delete workflow and the entire workspace is eradicated cleanly, leaving zero residual junk files on the core OS.

### Host-Pinned Session Hardening
Active sessions are dynamically bound to your exact IP address, browser signature (`User-Agent`), and domain routing. If a session cookie is intercepted laterally on an unsecure network, the engine triggers an immediate, hard session destroy.

> **Note:** One-Click isn't a wrapper that hides Linux; it is a smart, secure lens that amplifies it.

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
| --web-admin  | Create a backup of selected static site. |
| --web-create | Install a blank static html or php website. |
| --wp         | Basic wordpress and cron management. |
| --wp-admin   | Manage all aspects of wordpress such as staging, backups and SSL |
| --wp-create  | Install Wordpress with either nginx or apache. |
| --nodejs-admin | Start, stop and manage app. |
| --nodejs-create| Install a NodeJS app with either nginx or apache. |
| --db-admin   | Manage Databases and create temp front UI. |
| --ssl        | Install SSL for wordpress or any other virtual host. |
| --php        | Manage system-wide or per site php settings. |
| --version    | Check version |

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

# WordPress Automation Module

One-Click provides a fully automated WordPress orchestration and lifecycle management system designed to provision isolated, production-ready environments with minimal manual intervention.

The WordPress module is not simply an installer. It functions as a complete deployment engine responsible for orchestrating webserver configuration, database provisioning, PHP runtime isolation, SSL integration, filesystem structure, and operational lifecycle management.

Each WordPress deployment is treated as an independently isolated application environment with dedicated resources, security boundaries, and service-level separation.

## Features

- Fully automated WordPress deployment using WP-CLI
- Isolated Linux system users per deployment
- Dedicated PHP-FPM pools for each domain
- Automatic database provisioning with unique credentials
- NGINX and Apache virtual host automation
- SSL provisioning and renewal via Let's Encrypt
- Structured backup and restore workflows
- Deterministic filesystem layouts
- Optional Redis caching integration
- Domain-aware environment management
- Operational lifecycle tooling
- Environment isolation and resource control
- Automated service configuration and orchestration

## Deployment Workflow

The WordPress deployment workflow automates:

- filesystem provisioning
- isolated system user creation
- PHP runtime isolation
- database creation and credential generation
- webserver virtual host generation
- WordPress installation and configuration
- SSL provisioning
- baseline environment hardening
- operational registration

## Example Commands

### Create a New WordPress Site

```bash
one-click --wp-create
```

### WordPress Management

```bash
one-click --wp
```

```bash
one-click --wp-admin
```

### Install SSL for Existing Sites

```bash
one-click --ssl
```

### Backup and Restore Operations

```bash
one-click --wp-backup
```

## Environment Structure

Each WordPress deployment follows a deterministic filesystem structure.

### Application Files

```text
/etc/one-click/wordpress/<domain>/www
```

### Backups

```text
/etc/one-click/wordpress/backups/<domain>
```

### SSL Certificates

```text
/etc/letsencrypt/live/<domain>
```

## Isolation Model

Every WordPress deployment is isolated through:

- dedicated Linux system users
- independent PHP-FPM pools
- isolated filesystem ownership
- per-site process separation
- service-level resource boundaries
- environment-aware configuration management

This isolation model reduces cross-site impact and improves operational stability.

## Resource Management

One-Click supports resource-aware execution through systemd integration and isolated service control.

Deployments can operate with:

- CPU isolation
- memory isolation
- process-level separation
- workload-specific runtime control

## SSL Integration

SSL provisioning is handled through automated Let's Encrypt integration using Certbot.

The SSL workflow supports:

- automatic certificate issuance
- certificate renewal
- virtual host SSL configuration
- HTTPS redirect handling
- WordPress URL updates
- existing deployment integration

## Backup System

The WordPress module includes structured backup lifecycle management.

Supported operations include:

- local backups
- remote backups
- restore workflows
- multi-target backup profiles
- environment-aware backup organization

## Operational Features

The module includes operational tooling for:

- deployment management
- administrative access
- lifecycle orchestration
- environment inspection
- backup handling
- SSL management
- service visibility
- isolated runtime management

## Security Model

The WordPress environment is designed around a security-first deployment philosophy that prioritizes:

- isolated execution boundaries
- reduced privilege exposure
- unique credentials per deployment
- controlled filesystem ownership
- deterministic infrastructure layout
- automated baseline hardening
- service separation
- operational transparency

## Deployment Notes

- Each WordPress deployment operates under its own isolated system user
- Every site receives a dedicated PHP-FPM pool
- DNS records must resolve correctly before SSL issuance
- Port 80 must remain accessible during certificate validation
- SSL provisioning failures do not prevent HTTP deployment
- Credentials are generated or validated using enforced complexity requirements

## Design Philosophy

The WordPress module is designed to provide:

- reproducible deployments
- predictable operational workflows
- minimal manual configuration
- secure environment isolation
- transparent orchestration
- simplified lifecycle management
- structured infrastructure provisioning

while preserving direct operational visibility and Linux-native control.

# Static Website Automation Module

One-Click provides a fully automated static website deployment and lifecycle management system designed for secure, isolated, and production-ready hosting environments.

The static website module is not limited to basic file hosting. It functions as a complete provisioning and orchestration layer responsible for webserver configuration, filesystem isolation, SSL integration, deployment structure, and operational lifecycle management.

Each static website deployment is treated as an independently isolated application environment with dedicated ownership boundaries, webserver integration, and operational tooling.

## Features

- Fully automated static website deployment
- Isolated Linux system users per deployment
- Independent NGINX or Apache virtual host provisioning
- SSL provisioning and renewal via Let's Encrypt
- Deterministic filesystem layouts
- Structured backup and restore workflows
- Domain-aware environment management
- Automatic webroot provisioning
- Reverse proxy aware operation
- Operational lifecycle tooling
- Environment isolation and service separation
- Automated webserver integration and orchestration

## Deployment Workflow

The static website deployment workflow automates:

- filesystem provisioning
- isolated system user creation
- webroot generation
- virtual host configuration
- SSL provisioning
- baseline environment preparation
- deployment registration
- operational integration

## Example Commands

### Create a New Static Website

```bash
one-click --web-create
```

### Website Management

```bash
one-click --web
```

```bash
one-click --web-admin
```

### Install SSL for Existing Sites

```bash
one-click --ssl
```

### Backup and Restore Operations

```bash
one-click --web-backup
```

## Environment Structure

Each static website deployment follows a deterministic filesystem structure.

### Website Files

```text
/etc/one-click/sites/<domain>/www
```

### Backups

```text
/etc/one-click/sites/backups/<domain>
```

### SSL Certificates

```text
/etc/letsencrypt/live/<domain>
```

## Isolation Model

Every static website deployment is isolated through:

- dedicated Linux system users
- isolated filesystem ownership
- independent webserver configuration
- per-site service separation
- environment-aware configuration management

This isolation model improves operational stability and reduces cross-site exposure.

## Webserver Integration

One-Click supports automated integration with:

- NGINX
- Apache

The deployment workflow automatically handles:

- virtual host creation
- webroot configuration
- SSL integration
- HTTP to HTTPS handling
- service reloads and validation

## Resource Management

The static website module supports resource-aware operational management through Linux-native isolation and service orchestration.

Deployments can operate with:

- isolated ownership boundaries
- workload-aware organization
- service-level separation
- environment-specific configuration handling

## SSL Integration

SSL provisioning is managed through automated Let's Encrypt integration using Certbot.

The SSL workflow supports:

- automatic certificate issuance
- automated certificate renewal
- HTTPS virtual host integration
- redirect configuration
- existing deployment integration

## Backup System

The static website module includes structured backup lifecycle management.

Supported operations include:

- local backups
- remote backups
- restore workflows
- multi-target backup profiles
- environment-aware backup organization

## Operational Features

The module includes operational tooling for:

- deployment management
- site administration
- lifecycle orchestration
- environment inspection
- backup handling
- SSL management
- webserver visibility
- isolated environment management

## Security Model

The static website environment is designed around a security-first deployment philosophy that prioritizes:

- isolated execution boundaries
- controlled filesystem ownership
- deterministic infrastructure layout
- reduced privilege exposure
- service separation
- operational transparency
- secure deployment organization

## Deployment Notes

- Each website deployment operates under its own isolated system user
- DNS records must resolve correctly before SSL issuance
- Port 80 must remain accessible during certificate validation
- SSL provisioning failures do not prevent HTTP deployment
- Deployments follow deterministic filesystem organization under `/etc/one-click/sites`

## Design Philosophy

The static website module is designed to provide:

- reproducible deployments
- predictable operational workflows
- simplified hosting management
- secure environment isolation
- transparent orchestration
- minimal manual configuration
- structured infrastructure provisioning

while preserving direct operational visibility and Linux-native control.

# Node.js Environment Management

One-Click provides automated deployment, isolation, and lifecycle management for Node.js applications through workflow-driven orchestration and environment-aware provisioning.

The platform abstracts the complexity of manually configuring production-ready Node.js environments while preserving operational transparency and shell-native control.

## Features

- Automated Node.js application deployment
- Isolated runtime environments
- Reverse proxy configuration
- Automatic webserver integration
- Process lifecycle management
- Application startup orchestration
- Environment-aware deployment flows
- SSL integration
- Static and dynamic application support
- Runtime monitoring integration

## Supported Webservers

- NGINX
- Apache

## Deployment Workflow

The Node.js deployment workflow automates:

- application directory creation
- isolated system user provisioning
- runtime preparation
- dependency installation
- reverse proxy configuration
- webserver integration
- SSL provisioning
- service startup
- process registration

## Example Usage

```bash
one-click --nodejs-create
```

## Guided Deployment Flow

```text
Application Setup
        ↓
Environment Isolation
        ↓
Dependency Installation
        ↓
Reverse Proxy Configuration
        ↓
SSL Provisioning
        ↓
Service Startup
        ↓
Operational Registration
```

## Operational Features

One-Click provides operational tooling around Node.js environments including:

- application restart management
- runtime monitoring
- log visibility
- deployment automation
- process inspection
- isolated environment management
- service lifecycle orchestration

## Security Model

Node.js applications are deployed with a security-first isolation model that prioritizes:

- isolated system users
- controlled runtime environments
- reverse proxy protection
- minimized privilege exposure
- environment separation
- operational transparency

## Design Philosophy

The Node.js integration is designed to provide:

- reproducible deployments
- simplified operational workflows
- predictable environment management
- transparent runtime behavior
- reduced manual configuration burden

while preserving direct operational control over the underlying Linux environment.

# Adminer Integration

One-Click includes automated database management integration through Adminer, providing lightweight, temporary, and isolated web-based access to application databases without requiring permanently exposed database administration panels.

Unlike traditional hosting environments that expose persistent database management interfaces, One-Click generates secure time-bound access sessions that are tied directly to the target environment.

## Features

- Automated Adminer deployment
- Temporary authenticated access sessions
- Isolated database environment mapping
- Automatic credential injection
- Localhost and reverse-proxy aware operation
- Multi-database compatibility
- Session expiration and cleanup
- Domain-aware database discovery

## Supported Database Engines

- MySQL
- MariaDB
- PostgreSQL *(future support)*
- SQLite *(future support)*

## Security Model

Adminer sessions are intentionally ephemeral and are not designed to remain publicly exposed.

The integration prioritizes:

- temporary magic-link authentication
- isolated database visibility
- automatic session expiration
- minimized credential exposure
- no permanent database passwords in the UI
- environment-aware database access control

## Example Usage

```bash
one-click --db-admin
```

The command automatically:

1. Detects available databases
2. Maps the correct isolated environment
3. Generates a temporary authenticated Adminer session
4. Returns a secure access URL

## Workflow

```text
Database Detection
        ↓
Environment Resolution
        ↓
Temporary Session Generation
        ↓
Magic Link Creation
        ↓
Automatic Adminer Authentication
```

## Design Philosophy

The Adminer integration is intended to provide:

- fast operational access
- minimal setup overhead
- secure temporary administration
- reduced credential handling
- lightweight database management

without introducing the attack surface commonly associated with permanently exposed database administration panels.

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
designed to evaluate infrastructure quality, identify bottlenecks, and
provide reproducible benchmark reporting with shareable historical results.

It delivers a structured benchmarking workflow suitable for:

- VPS validation
- Dedicated server verification
- Cloud instance comparison
- Pre-deployment testing
- Post-migration performance checks
- Long-term infrastructure performance tracking

### Benchmark Coverage

OCB evaluates multiple critical subsystems:

- **CPU performance** – single-threaded and multi-threaded computational workloads  
- **Memory performance** – sequential read/write bandwidth and latency analysis  
- **Disk performance** – sequential and random I/O throughput testing  
- **Network latency** – multi-target latency measurement with automatic ranking  
- **System profiling** – virtualization detection, CPU model, kernel, architecture, and platform details  

### Network Test Logic

- All network targets are latency-tested before extended benchmarking  
- Targets are automatically sorted by lowest round-trip latency  
- Bandwidth and transfer tests execute in ranked order  
- Provides more consistent and comparable benchmark results across environments  

### Historical Result API

OCB now integrates with a centralized benchmark reporting API.

After each benchmark completes:

- Results can be securely submitted to the reporting platform  
- A unique public result URL is generated automatically  
- Historical benchmark reports remain accessible for future comparison  
- Engineers can share benchmark URLs similarly to platforms such as Geekbench  
- Enables performance trend analysis across hardware changes, migrations, or provider comparisons  

This allows benchmark results to become portable, verifiable, and easy to reference during infrastructure evaluations, procurement reviews, or support investigations.

### Design Characteristics

- Non-destructive and safe for production systems  
- Automatic dependency handling  
- Structured table output with optional scoring indicators  
- Runs inside a managed tmux session to prevent interruption  
- Minimal operator interaction required  
- No persistent system modifications  

OCB is designed for engineers who require fast, repeatable, and shareable
performance benchmarking without manually deploying heavyweight testing suites.

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

- [Adminer by vrana](https://github.com/vrana/adminer/)
  Adminer is a full-featured database management tool written in PHP. One-Click utilizes it as our single token database management GUI.

One-Click may embed these projects directly or incorporates concepts,
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

