# ADA — Adaptive Computation & Multi-Agent Reasoning Platform

[![Release](https://img.shields.io/badge/release-v0.3.0-blue.svg)](https://github.com/tzykv1n/ada-releases/releases)
[![Python](https://img.shields.io/badge/python-3.10%20%7C%203.11%20%7C%203.12-blue)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)](https://www.kernel.org/)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](LICENSE)

ADA is an open-access scientific reasoning research framework exploring test-time adaptive computation and multi-agent systems.

ADA enables models to dynamically allocate reasoning effort—evaluating mathematical word problems using structured Solver-first derivation, mechanical evidence verification, and on-demand planning assistance.

---

## 1. Current Release: `v0.3.0`

- **Version**: `0.3.0`
- **Release Date**: October 2026
- **Supported OS**: Linux (x86_64, aarch64)
- **Supported Python**: Python 3.9, 3.10, 3.11, 3.12, 3.13, 3.14
- **Hardware Support**:
  - Local CPU: Hardware diagnostics, static checks, configuration, and result exploration.
  - Remote Acceleration: Kaggle dual NVIDIA T4 GPUs (32 GiB aggregate VRAM) for heavy neural model execution.

---

## 2. Quick Installation (Authentication-Free)

Public users can install ADA directly without GitHub authentication or private repository access:

```bash
curl -fsSL https://raw.githubusercontent.com/tzykv1n/ada-releases/master/install.sh | bash
```

### Unattended Installation
```bash
curl -fsSL https://raw.githubusercontent.com/tzykv1n/ada-releases/master/install.sh | bash -s -- --yes
```

### Specific Version Installation
```bash
curl -fsSL https://raw.githubusercontent.com/tzykv1n/ada-releases/master/install.sh | bash -s -- --version 0.3.0
```

### Installation from Direct Tarball Archive
```bash
# 1. Download release archive and checksums
curl -fsSL -O https://github.com/tzykv1n/ada-releases/releases/download/v0.3.0/ada-0.3.0.tar.gz
curl -fsSL -O https://github.com/tzykv1n/ada-releases/releases/download/v0.3.0/checksums.sha256

# 2. Verify SHA-256 cryptographic checksum
sha256sum --check --ignore-missing checksums.sha256

# 3. Extract and install
tar -xzf ada-0.3.0.tar.gz
cd ada-0.3.0
./install.sh
```

---

## 3. Cryptographic Verification

All official releases provide published SHA-256 digests in `checksums.sha256`. Verify downloaded files prior to installation:

```bash
sha256sum -c checksums.sha256
```

Example verified output:
```text
ada-0.3.0.tar.gz: OK
ada-0.3.0-py3-none-any.whl: OK
install.sh: OK
```

---

## 4. Usage & Command Reference

The `ada` command provides an interactive shell, diagnostics, and experiment tracking:

### Launch Interactive TUI
```bash
ada
```
Launches the full-screen terminal interface with keyboard navigation, model configuration, and experiment explorer.

### System & Hardware Diagnostics
```bash
ada system
```
Displays host CPU cores, memory pressure, CUDA/GPU detection, model capacity recommendations, and Kaggle backend authentication status.

### Health Check ("Doctor")
```bash
ada doctor
```
Runs comprehensive self-diagnostics verifying virtual environment health, launcher symlinks, dependencies, and cache integrity.

### Stage 1 Adaptive Reasoning (Dry-Run Preview)
```bash
ada run stage1-adaptive --dry-run
```
Validates the execution preflight, inspects hardware feasibility, computes model memory footprint, and reports whether Local or Kaggle execution will be utilized.

### Inspect Verified Results & Benchmarks
```bash
ada results
```
Displays verified Stage 1 evaluation results on GSM8K Dev #85–134.

---

## 5. Upgrade and Uninstall

### Check for Updates & Upgrade
```bash
# Check if an update is available (non-invasive query against public release repo)
ada upgrade --check

# Perform automated update
ada upgrade
```

### Clean Uninstall
```bash
# Using the installer
./install.sh --uninstall

# Or manually:
rm -f ~/.local/bin/ada
rm -rf ~/.local/share/ada
```
*Note: Your cached benchmark outputs in `~/.cache/ada` remain preserved.*

---

## 6. Architecture & Features in `v0.3.0`

- **Hardware-Aware Preflight**: Probes host memory, GPU availability, and Python dependencies before execution. Automatically routes large neural workloads to authenticated Kaggle remote GPUs when local CPU resources are under-provisioned.
- **Solver-First Adaptive Reasoning**: Prioritizes direct derivation, invoking planning assistance only when a mechanical verifier detects calculation contradictions or when the model explicitly requests decomposition.
- **Evidence-Gated AST Verifier**: Deterministic arithmetic evaluation using restricted Python AST with zero arbitrary code execution, bounded expression depth, and numeric sanity checks.
- **Process Supervisor Isolation**: Child worker processes are contained in isolated process groups (`ada-safe`), preventing session drops and system memory thrashing.

---

## 7. Known Limitations

- **Model Execution Policy**: Full model inference requires either an NVIDIA GPU with at least 8 GiB VRAM locally or a configured Kaggle account. On CPU-only hosts without local PyTorch/CUDA, `ada run` automatically selects the remote Kaggle cluster.
- **Dataset Governance**: By scientific design, ADA's evaluation runner strictly accesses only approved development partitions (GSM8K Dev #85–134). Reserved holdout partitions remain sealed to prevent benchmark contamination.

---

## 8. Release History

- **v0.3.0 (October 2026)**:
  - First public distribution release via `ada-releases`.
  - Added hardware-aware execution target routing (`auto`, `prefer-local`, `prefer-kaggle`, `local-only`, `kaggle-only`).
  - Added deterministic Evidence-Gated AST verifier.
  - Added process supervisor isolation with automated log capture.
  - Implemented 100% authentication-free public installer with SHA-256 validation.
- **v0.2.0 (Historical / Frozen Reference)**:
  - Phase 1 frozen milestone reference (`5216626`).

---

## 9. Issue Reporting & Support

If you encounter an installation failure, dependency conflict, or bug, please open an issue on the public distribution repository:

**Public Issue Tracker**: [https://github.com/tzykv1n/ada-releases/issues](https://github.com/tzykv1n/ada-releases/issues)

Please include:
- Output of `ada system` or `install.sh --dry-run`
- Your Linux distribution and Python version (`python3 --version`)
- Error messages and supervisor log from `~/.local/state/ada/supervisor/runs/`

---

## 10. License

ADA is open-source software distributed under the terms of the **Apache License, Version 2.0**.
See [LICENSE](LICENSE) for details.
