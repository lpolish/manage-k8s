# Kubernetes Manager (`manage_k8s.sh`)

A comprehensive command-line tool for managing Kubernetes applications with ease.

## Prerequisites

- A Unix-like operating system (Linux, macOS, or WSL on Windows)
- `kubectl` (will be installed automatically if missing)

## Features

- `🚀` **Application Management**: Deploy, delete, restart, and scale applications
- `📊` **Health Monitoring**: Detailed application and cluster status views
- `⏯️` **Pause/Resume**: Scale to 0 to pause, scale up to resume
- `📝` **Log Management**: Easy log viewing for troubleshooting
- `🔄` **Automation**: Supports scripting for CI/CD pipelines
- `🗂️` **Backup**: Namespace resource backups
- `🧹` **Cleanup**: Remove completed/failed pods

## Installation

You can install k8s-manager using either of these methods. The installer will automatically check for kubectl and offer to install it if missing.

### Method 1: Direct download and install (Interactive)

```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/manage-k8s/refs/heads/master/install.sh | bash
```

### Method 2: Manual download and install

```bash
# Download the installer
curl -LO https://raw.githubusercontent.com/lpolish/manage-k8s/refs/heads/master/install.sh
# Make it executable
chmod +x install.sh
# Run the installer
./install.sh
```

### Uninstallation

To uninstall the script, you can use either of these methods:

```bash
# Method 1: Using the installer
./install.sh --uninstall

# Method 2: Using the script itself
k8s-manager uninstall
```

The script will be installed to `~/.local/bin/k8s-manager` and will be available in your PATH after restarting your shell or sourcing your shell's RC file.

### Supported Package Managers

The installer supports the following package managers for kubectl installation:
- apt-get (Debian, Ubuntu, and derivatives)
- dnf (Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux)
- brew (macOS)

For other systems, the installer will provide instructions for manual kubectl installation.

## Usage

```
k8s-manager [COMMAND] [OPTIONS]
```

### Basic Commands

| Command          | Description                          | Example                          |
|-----------------|--------------------------------------|----------------------------------|
| `list-apps`     | List all applications                | `k8s-manager list-apps`         |
| `app-status`    | Show application details             | `k8s-manager app-status myapp`  |
| `deploy`        | Deploy from YAML                     | `k8s-manager deploy app.yaml`   |
| `scale`         | Scale replicas (0=pause)             | `k8s-manager scale myapp 3`     |
| `restart`       | Restart application                  | `k8s-manager restart myapp`     |
| `logs`          | View application logs                | `k8s-manager logs myapp`        |

### Advanced Options

```
-n, --namespace NAMESPACE  # Target specific namespace
-a, --all-namespaces     # Operate across all namespaces
-v, --verbose            # Show detailed output
```

## Examples

1. **Deploy and monitor an application**:
```bash
k8s-manager deploy myapp.yaml
k8s-manager app-status myapp
k8s-manager logs myapp
```

2. **Pause a production service**:
```bash
k8s-manager scale production-api 0 -n prod
```

3. **Backup a namespace**:
```bash
k8s-manager backup important-ns -n staging
```

## License

© 2025 [Luis Pulido Diaz](LICENSE) (MIT LICENSE)