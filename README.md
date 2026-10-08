# oops

> **Process tree visualizer and signal controller with systemd slice grouping for the openOODA era.**  
> *A drop-in `ps`/`pstree` alternative written in pure openOODA, featuring native systemd slice classification (`system.slice`, `user.slice`), hierarchical tree visualization, capability-gated signal dispatch (`ProcessCap`), and a streaming Model Context Protocol (MCP) server.*

Part of [openOODA-tools](https://github.com/openOODA-tools).

---

## 1. Installation

`oops` has zero runtime dependencies. It compiles to a standalone native binary linked directly with libc.

### Universal Web Installer
Installs the standalone native binary to `/usr/local/bin` (or `~/.local/bin`):

```bash
curl -fsSL https://openooda-tools.github.io/oops/install.sh | bash
```

### Debian / Ubuntu (APT)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oops/install.sh | bash -s -- --apt

# Or manual package install
sudo dpkg -i oops_0.2.0-1_amd64.deb
```

### Fedora / RHEL / CentOS (DNF)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oops/install.sh | bash -s -- --dnf

# Or manual RPM install
sudo dnf install ./oops-0.2.0-1.*.x86_64.rpm
```

### Arch Linux (PKGBUILD)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oops/install.sh | bash -s -- --arch

# Or manual build via packaging/PKGBUILD
cd packaging && makepkg -si
```

### Clean Uninstaller
To cleanly remove `oops` and any installed package manager entries:

```bash
# Automated via standalone uninstaller
curl -fsSL https://openooda-tools.github.io/oops/uninstall.sh | bash

# Or via installer flag
curl -fsSL https://openooda-tools.github.io/oops/install.sh | bash -s -- --uninstall

# Or preview removal without making changes (dry-run)
curl -fsSL https://openooda-tools.github.io/oops/uninstall.sh | bash -s -- --dry-run
```

---

## 2. Usage & Features

### Process Tree Visualization
View processes organized hierarchically with branch glyphs and systemd slice badges:

```bash
# Render complete process tree (default)
oops

# Explicit tree mode
oops -t

# Render tree with ASCII connectors (|--, \--)
oops --ascii

# Flat table view
oops -l

# Target specific process subtree or PID
oops -p 1

# Filter processes belonging to systemd system slice
oops -s system

# Filter processes belonging to user sessions
oops -s user

# Suppress ANSI color output
oops --no-color

# Search processes by name
oops sshd
```

### Signal Control
Send POSIX signals safely under `ProcessCap`:

```bash
# Send SIGTERM (default) to process
oops -k TERM -p 1234

# Send SIGKILL
oops -k KILL -p 1234
```

### Model Context Protocol (MCP) Server
`oops` features a native Model Context Protocol (MCP) stdio server allowing AI pair programmers and LLM coding assistants to inspect and manage running tasks:

```bash
oops --mcp
```

#### Exposed MCP Tools:
- `process_tree`: Returns structured process tree or table (`format`: `tree`, `table`, `json`; optional `slice` filter).
- `find_process`: Finds processes matching a given name or substring, including `rss_kb` memory metrics.
- `process_details`: Returns complete metadata for a target PID (`pid`, `ppid`, `comm`, `state`, `slice`, `rss_kb`, `threads`, `cgroup_path`, `cmdline`).
- `send_signal`: Dispatches POSIX signals to a target PID under explicit capability authorization with strict positive PID validation.

---

## 3. License

Apache License 2.0. See [LICENSE](LICENSE) for details.