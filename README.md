# One-Click Toolkit
![One-Click Logo](https://as214354.network/one-click.png)
# One-Click — Linux Infrastructure Automation Toolkit

One-Click is an advanced operational console engineered for power users, developers, and sysadmins who demand maximum control with zero infrastructure bloat. Built on a strict **security-first-by-design** architecture, One-Click completely redefines server management by replacing vulnerable, resource-heavy web UIs with a lean, terminal-driven automation matrix.

By abstracting complex Linux primitives into predictable, guided workflows, One-Click eliminates the syntax burden of server administration while maintaining total architectural transparency.

## Features

One-Click delivers streamlined workflows for essential system administration tasks:

- **OS Reinstallation**
- **VPS Migration & Portability**
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
It is designed to operate safely with caching, fallback mirrors, and validation safeguards.

# Fleet Manager (Cluster Orchestration)

One-Click includes a built-in fleet orchestration engine powered by Ansible that allows multiple servers to be managed as a single infrastructure unit.

The fleet engine adopts a secure hub-and-spoke architecture where the controller orchestrates all operations while reducing unnecessary public exposure across member nodes.

Fleet operations include:

- Cluster initialization
- Node registration
- SSH trust management
- Configuration synchronization
- Hardware auditing
- Distributed benchmarking
- Remote file transfers
- Site cloning and restoration
- Fleet-wide updates
- Fleet-to-Fleet VPS migration orchestration
- Centralized firewall management

## Core Commands

```
one-click fleet init
one-click fleet add <ip> <hostname> [port]
one-click fleet verify
one-click fleet update
one-click fleet audit
one-click fleet bench
one-click fleet update-keys
one-click fleet put <host> <src> <dest>
one-click fleet get <host> <src> <dest>
one-click fleet raw <host> "<command>"
one-click clone-site example.com peer-node
one-click restore-site example.com peer-node
```
Fleet members are hardened by default.

## Features include:

- SSH key-based authentication
- Reduced public attack surface
- Controller-driven orchestration
- Secure peer communication
- Automated trust relationships


---

# VPS Engine

One-Click can transform the controller and fleet members into an orchestrated KVM virtualization platform.

Virtual machines can be provisioned locally or on remote hypervisors and immediately integrated into the management ecosystem.

## Features include:

- KVM provisioning
- NAT deployments
- Public IP deployments
- Snapshot management
- Backup management
- Safeguarded Fleet-to-Fleet VPS migration
- Operating system reinstall
- Patch management
- Automatic fleet integration

## Example
```
one-click --vps create --target hypervisor1 --name db1 --image ubuntu24 --cpu 2 --ram 4G --disk 40G --mode nat
one-click --vps snapshot create --target web1 --name backup_v1
one-click --vps migrate --target hypervisor2 --name <vm_name>
one-click --vps import
one-click --vps export --name <vm_name>
one-click --vps reinstall -n <name> -i <image> --password <password> -l <optional language>
```
## Available Operations
- one-click --vps create
- one-click --vps delete
- one-click --vps edit
- one-click --vps reinstall
- one-click --vps snapshot
- one-click --vps backup
- one-click --vps patch
- one-click --vps migrate
- one-click --vps import
- one-click --vps export --name <vm_name>
- one-click --vps start
- one-click --vps stop

## VPS Migration & Portability

One-Click now uses the VPS Engine for all supported migration workflows. There is no separate standalone migration tool.

### Fleet-to-Fleet Migration

```bash
one-click --vps migrate --target <destination_hypervisor> --name <vm_name>
```

Fleet-to-Fleet migration moves the actual KVM virtual machine between trusted One-Click hypervisors.

The workflow operates at the hypervisor layer rather than inside the guest operating system.

Safeguards include:

- Source and destination Fleet connectivity, sudo, libvirt, and rsync validation before any shutdown
- Migration serialization to prevent overlapping Fleet VPS moves
- Destination VM-name and storage-path collision checks before transfer
- Discovery of the VM's real file-backed libvirt disks, attached media, and UEFI NVRAM
- Refusal to silently migrate unsupported storage layouts or incomplete backing chains
- Destination free-space validation before the source VM is stopped
- Clean guest shutdown before disk synchronization
- Destination-side staging instead of overwriting final VM paths during transfer
- Transferred file-size validation before activation
- Destination libvirt definition and boot validation before the virtualization inventory is changed
- Fleet-key guest validation through the recorded cluster-private address when available
- Automatic rollback before commit: incomplete destination assets are removed and the source VM is restarted with its previous autostart behavior restored
- Inventory commit only after destination validation
- The source VM is retained after success, shut down with autostart disabled, providing a rollback copy until the operator chooses to remove it

Fleet-to-Fleet migration is the preferred path when both hypervisors are already trusted Fleet members and the goal is to move the existing VM itself.

### Import an External VPS into Fleet

```bash
one-click --vps import
```

Import moves a complete supported Linux VPS into a newly provisioned One-Click Fleet VM.

The source is inspected before the destination is built. One-Click records the source operating-system profile, architecture, hostname, CPU, memory, total disk size, and used capacity, then enters the normal VPS creation path to build a compatible replacement on the selected Fleet hypervisor.

The replacement VM becomes the migration initiator and pulls the source over SSH.

Import safeguards include:

- Temporary bootstrap access used only to inspect and prepare the external source
- Source inspection before replacement provisioning
- Like-for-like operating-system/profile and architecture checks
- Normal One-Click VPS create workflow for the replacement
- Replacement-generated temporary pull identity
- Permanent Fleet management keys mapped to source `oneclick` before transfer
- Verification of replacement-to-source SSH, sudo, and rsync access
- Removal of the temporary source bootstrap account before migration starts
- Initial whole-system synchronization while the source remains online
- Detected application and stateful services stopped only for the final synchronization
- Destination boot, filesystem mount, network, SSH host, machine, WireGuard, Fleet, and virtualization identity preserved
- Source users, groups, applications, services, and `oneclick` home migrated using numeric ownership without UID/GID remapping
- `/etc/passwd`, `/etc/shadow`, `/etc/group`, and `/etc/gshadow` staged until final cutover
- Final PAM synchronization before cutover
- Staged account database swapped immediately before reboot rather than opening a new SSH session in a half-migrated userspace
- Post-reboot Fleet-key validation
- Source VPS retained for operator validation instead of being deleted automatically

If migration fails after source application services have been stopped, One-Click attempts to restart those services automatically.

After a successful import, source application services remain stopped to prevent split-brain until the replacement has been validated.

Migration state is retained under:

```text
/etc/one-click/virtualization/migrations/<migration-id>/state.json
```

### Export a Fleet VPS to an External Replacement

```bash
one-click --vps export --name <vm_name>
```

Export is the reverse portability workflow. It moves a Fleet VPS into a fresh, compatible external Linux replacement while keeping the original Fleet VPS available for rollback and validation.

The operator prepares the external replacement using the temporary bootstrap block generated by One-Click. The external replacement then pulls the Fleet source over SSH.

Export safeguards include:

- Fresh external replacement bootstrap using a temporary `ocmig_*` account
- Like-for-like operating-system and architecture validation
- External destination pulls the source rather than exposing a push-oriented source workflow
- First whole-system synchronization while the Fleet source remains online
- Application and stateful services stopped only for the final synchronization
- External destination boot, network, SSH, and machine identity preserved
- Source `oneclick` home and account ownership migrated naturally without UID/GID remapping
- Source account database staged until cutover
- Final PAM synchronization before account activation
- Atomic staged account swap followed immediately by destination reboot
- Post-reboot validation using the migrated source `oneclick` account
- Permanent Fleet controller key validation before the temporary export key is removed
- Temporary export key retained if the permanent key does not authenticate, preventing loss of the last known-good access path
- Original Fleet VPS retained after success
- Original application services left stopped after successful cutover to prevent split-brain

The original Fleet VPS is not deleted automatically. Validate the external replacement first, then remove the old VPS through the normal Fleet VPS deletion workflow when ready.

### Choosing the Correct Migration Path

| Requirement | Command | Migration Layer |
| :--- | :--- | :--- |
| Move an existing KVM VM between trusted Fleet hypervisors | `one-click --vps migrate` | Hypervisor / VM artifact |
| Bring an external Linux VPS into Fleet | `one-click --vps import` | Guest filesystem into a new Fleet replacement |
| Move a Fleet Linux VPS to an external provider or host | `one-click --vps export --name <vm_name>` | Guest filesystem into a fresh external replacement |

Fleet-to-Fleet migration moves the original virtual machine artifact.

Import and export move the operating-system userspace and workload into a replacement machine while intentionally preserving destination-specific infrastructure identity.


# One-Click Edge Proxy

The proxy engine exposes services running inside private NAT environments without requiring public addresses on the guest itself.

HAProxy runs at the hypervisor edge and securely forwards traffic into backend workloads.

## Features include:

- HTTP proxying
- HTTPS proxying
- TCP forwarding
- Domain routing
- Port forwarding
- NAT traversal

## Example

```
one-click --proxy --target analytics-vm --website dashboard.example.com --proto https
one-click --proxy --target web1 --source 22 --port 8822
```
## Available Operations

- --target	Destination VM
- --website	Domain name
- --proto	http, https, tcp
- --source	Internal application port
- --port	Public listener port


---

# WireGuard Mesh Networking

One-Click includes a WireGuard mesh engine that creates secure overlay networks between infrastructure components and external clients.

The system automatically generates cryptographic profiles and distributes network access safely.

## Features include:

- Overlay networking
- Client profile generation
- Peer management
- Traffic isolation
- Secure remote access
- Connection monitoring

## Commands

```
one-click --wireguard add-user
one-click --wireguard delete-user
one-click --wireguard view
```

# Direct SSH NAT Access

Virtual machines deployed inside NAT environments remain accessible without exposing public ports.
This allows administrators to directly access isolated systems without manually configuring SSH tunnels.

One-Click automatically creates secure access tunnels.

## Example

```
one-click --ssh <peer-name|peer-ip>
```

---

# DNS Manager & Replication

One-Click includes a distributed DNS orchestration engine built around BIND if used or can be API based etc.

The DNS manager synchronizes zone files and automatically propagates changes across fleet members.

## Features include:

- BIND management
- Zone creation
- Secure replication
- Multi-region synchronization
- Automatic peer updates
- Redundant name services

This enables geographically distributed infrastructure to maintain consistent naming resolution without synchronization drift.

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

```
one-click --wp
one-click --wp-admin
one-click --wp-backup
```

### Install SSL for Existing Sites

```
one-click --ssl
```

## Environment Structure

Each WordPress deployment follows a deterministic filesystem structure.

### Application Files

```
/etc/one-click/wordpress/<domain>/www
-  Backups
/etc/one-click/wordpress/backups/<domain>
- SSL Certificates
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

The WordPress module includes structured backup lifecycle management as well as integrated with fleet for seamless migration and backup across fleet peers.

Supported operations include:

- local backups
- remote backups
- Fleet management
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

```
one-click --web-create
one-click --web
one-click --web-admin
one-click --web-backup
```

### Install SSL for Existing Sites

```bash
one-click --ssl
```

## Environment Structure

Each static website deployment follows a deterministic filesystem structure.

### Website Files

```
/etc/one-click/sites/<domain>/www
- Backups
/etc/one-click/sites/backups/<domain>
- SSL Certificates
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

### Dry Run

The dry-run engine executes firewall logic in a parallel simulation namespace that never touches live iptables state.
It evaluates:

- sensitive port impact
- service reachability
- administrative lockout risk
before allowing execution into the live transaction layer.

#### Dry-Run Flow

```
INPUT → SIMULATION → RISK ANALYSIS → DECISION → (ALLOW / BLOCK)
```

#### Example safe rule usage and output
```
one-click engine --dry-run "allow nginx"
```
```
╔════════════════════════════ [ CRITICAL WARNING ] ════════════════════════════╗
║ [DRY-RUN] Action: DROP detected on Port 443 (HTTPS (Web Traffic)).           ║
║ [DRY-RUN] This is a CORE SERVICE. Proceeding may cause connectivity issues!  ║
╚══════════════════════════════════════════════════════════════════════════════╝
[DRY-RUN] The following commands will be executed:
[DRY-RUN] iptables -t filter -A INPUT -p tcp -m multiport --dports 80,443 -j DROP
[DRY-RUN]: Apply ALL rules? (y|n): y
[DRY-RUN] Preparing dry run isolated environment for safe testing...
[DRY-RUN] Verifying system accessibility...
[DRY-RUN][SUCCESS] Service sshd (Port 22) remains accessible.
[DRY-RUN][SUCCESS] Service mariadbd (Port 3306) remains accessible.
[DRY-RUN][SUCCESS]  Port 443 (nginx) will successfully remain filtered/blocked.

[DRY-RUN][SUCCESS] Service node (Port 5000) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5001) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5002) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5003) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5004) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5005) remains accessible.
[DRY-RUN][SUCCESS]  Port 80 (nginx) will successfully remain filtered/blocked.

[DRY-RUN][SUCCESS] Rules passed dry-run test.
Would you like to apply these rules now? (y|n): y
[INFO]: Rule applied: iptables -t filter -A INPUT -p tcp -m multiport --dports 80,443 -j DROP
[SUCCESS]: All rules successfully applied.

[SAFETY]: Firewall will auto-rollback in 10 seconds unless confirmed.
[USER]: Confirm firewall is functional? (y|yes): y
[SUCCESS]: Firewall changes confirmed and committed.

[SAFETY]: Firewall configuration will rollback in 10 seconds if not confirmed functional!
[USER]: Confirm rule is safe? (y|yes to keep): y

[SUCCESS]: Rule confirmed and persisted in memory.
[INFO]: Please save your rules with one-click engine backup
[SUCCESS]: Firewall rules persisted.
```

#### Example dangerous rule usage and output
```
one-click engine --dry-run 'drop ssh'
```
```
[DRY-RUN] Initializing security simulation namespace...
[DRY-RUN] Loading sensitive port profile...

╔════════════════════════════ [ CRITICAL WARNING ] ════════════════════════════╗
║ [DRY-RUN] Action: DROP detected on Port 22 (SSH (Remote Access)).            ║
║ [DRY-RUN] This is a CORE SERVICE. Proceeding may cause connectivity issues!  ║
╚══════════════════════════════════════════════════════════════════════════════╝
[DRY-RUN] The following commands will be executed:
[DRY-RUN] iptables -t filter -A INPUT -p tcp --dport 22 -j DROP
[DRY-RUN]: Apply ALL rules? (y|n): y
[DRY-RUN] Preparing dry run isolated environment for safe testing...
[DRY-RUN] Verifying system accessibility...
[DRY-RUN][FAIL] FATAL: sshd (Port 22) will be BLOCKED! This will cause a lockout if applied.

[DRY-RUN][SUCCESS] Service mariadbd (Port 3306) remains accessible.
[DRY-RUN][SUCCESS] Service nginx (Port 443) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5000) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5001) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5002) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5003) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5004) remains accessible.
[DRY-RUN][SUCCESS] Service node (Port 5005) remains accessible.
[DRY-RUN][SUCCESS] Service nginx (Port 80) remains accessible.
[DRY-RUN][FAIL] Firewall rules failed dry-run test.
[DRY-RUN] Dry run failed. Exiting without applying rules.
```
#### Rule-Engine Security Model

This system enforces a three-layer safety architecture:

1. Simulation Layer (Dry Run)
- No live firewall changes
- Full risk prediction
- Service impact analysis
2. Transaction Layer (Apply)
- Snapshot before changes
- Controlled execution
- Temporary unsafe state allowed
3. Confirmation Layer (Rollback Protection)
- Time-bound validation window
- Automatic rollback if not confirmed
- Manual override possible

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

A dual-mode logging suite providing both an interactive terminal interface and real-time browser-based monitoring dashboards for single nodes and multi-node clusters.

### Features
- **Interactive Terminal Browser:** Arrow-key navigation, live preview panes, and `journalctl` service inspection.
- **Web-Based Log Analytics (GoAccess):** Real-time web server metrics, bandwidth tracking, and multi-node HTTP access stream parsing.
- **Native System Log Console:** Real-time multi-node system log streaming with Tailwind-powered color-coded severity levels (`ERROR`, `WARN`, `INFO`), regex search, host tab switching, and persistent log archiving.
- **Strict Web Security Architecture:**
  - **Tokenized Session Paths:** Web interfaces are served under randomized, high-entropy token paths (e.g., `/<32-char-token>/`), preventing directory scanning or unauthorized index access.
  - **Dynamic Client IP Isolation:** Automatically detects the connecting SSH client (supporting dual-stack IPv4 and encapsulated `[IPv6]` endpoints) and applies temporary firewall rules (`iptables` / `ip6tables`) locking access exclusively to your IP.
  - **Ephemeral Port Allocation:** Dashboards bind to dynamically selected high ports, avoiding persistent background listeners.
  - **Automatic Session Expiry & Teardown:** VHosts, stream harvesters, web server aliases, and firewall grants automatically collapse upon session expiration.
  - **Container-Free & Unbuffered:** Serves live streams natively through existing web servers (Nginx/Apache) without container dependencies or registry overhead.
- **Safe Maintenance Controls:** Direct log vacuuming, service-level log flushing, and automated session cleanup.

**Command:** `one-click logs` or `one-click log-browser`  

**Terminal Browser Subcommands:**

| Keybind | Action | Description |
| :--- | :--- | :--- |
| `Enter` | **View Service Log** | Opens full pager stream for selected `journalctl` unit |
| `Ctrl+F` | **Flush Unit Logs** | Rotates and vacuums logs exclusively for the selected service |
| `Ctrl+A` | **Vacuum All Logs** | Truncates and vacuums all system journal logs across the host |
| `Ctrl+E` | **Back** | Return to previous management menu |

**Live Web Console Subcommands:**

| Subcommand | Engine | Description |
| :--- | :--- | :--- |
| `one-click logs --live` | GoAccess | Real-time web access analytics dashboard over tokenized WebSocket |
| `one-click logs --syslog` | Tailwind / Native UI | Multi-node tail-based system log console with live filtering & search |

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

One-Click relies primarily on standard, widely available system binaries and distribution packages. It avoids custom binary compilation during normal operation, pulling dependencies like GoAccess directly from standard package repositories or verified sources, and utilizing Adminer as a single-file PHP management script and Tailwind CSS via official CDN distributions.

### Web Dashboard & Session Security
Web-based GUIs and live streaming log dashboards operate under strict ephemeral lockdown principles:

- **Tokenized Single-Session Endpoints:** Web interfaces are served under randomized, high-entropy token paths (e.g., `/<32-char-token>/`), preventing unauthorized path traversal or scanning.
- **Dynamic Client IP Isolation:** Automatically detects the requesting client's connecting address (IPv4 or dual-stack IPv6) and enforces strict firewall rules (`iptables` / `ip6tables`) to lock web ports exclusively to that single IP during the active session.
- **Ephemeral Port Allocation:** Web consoles bind to non-standard, dynamically generated ephemeral ports, avoiding persistent background listeners.
- **Timed Auto-Destruction:** All VHost configurations, web server aliases, background stream harvesters, and firewall grants automatically collapse and clean up upon session expiration.
- **Container-Free Execution:** Integrates directly with native host web servers (Nginx, Apache, or Httpd) using unbuffered streams without external container runtime vulnerabilities or registry dependencies.

### Core Utilities
System operations rely on standard toolchains:

- curl
- tmux
- rsync
- rclone
- dd
- sgdisk
- GoAccess
- Adminer (PHP script)
- Tailwind CSS
- standard GNU/Linux utilities

Outside of verified utilities (such as Geekbench, GoAccess, or Adminer), no unverified custom binaries are compiled or downloaded during normal operation.

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

Certain modules (for example reinstall, VPS migration, and recovery) perform privileged
operations including VM storage movement, disk modification, or bootloader changes.

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
- Transport & Networking: OpenSSH client/server, iptables / ip6tables
- Supported Web Servers: Nginx or Apache (httpd / apache2)

Additional optional packages (e.g., ansible, goaccess, journalctl, jq) are detected and installed automatically as required by specific operational modules.

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

- [GoAccess by allinurl](https://github.com/allinurl/goaccess)  
  Provided inspiration and structural patterns for lightweight, real-time log analysis, stream harvesting, and embedded web-based analytics dashboards.

- [Tailwind CSS by Tailwind Labs](https://github.com/tailwindlabs/tailwindcss)  
  Utility-first CSS framework utilized for rendering responsive, dark-mode web dashboards without external build dependencies.

One-Click may embed these projects directly or incorporates concepts,
ideas, and selected implementation approaches adapted to fit its modular
architecture.

Credit and appreciation are extended to the maintainers and contributors of
these projects for their work in advancing open infrastructure tooling.

## Disclaimer

One-Click is a modular toolkit.

Not all modules perform low-level system operations.

Certain tools — such as OS reinstallation, VPS migration, or boot recovery — may perform operations including:

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

