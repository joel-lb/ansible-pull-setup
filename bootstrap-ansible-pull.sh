#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Config (override via env if needed)
# ============================================================
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3.11}"
ANSIBLE_VERSION="${ANSIBLE_VERSION:-}" # e.g.  ">=2.16" or "13.4.0"
PYJWT_VERSION="${PYJWT_VERSION:-}"     # e.g. "2.9.0"
NETADDR_VERSION="${NETADDR_VERSION:-}" # e.g. "1.3.0"

log() { echo "[ansible-pull-demo-bootstrap] $*" >&2; }

# ============================================================
# OS packages (Alma/RHEL 9.6 style)
# ============================================================
install_os_packages() {
  local PKG_MGR
  PKG_MGR=$(command -v dnf || command -v yum)

  $PKG_MGR -y update

  $PKG_MGR -y install \
    git \
    python3.11 \
    python3.11-pip \
    openssh-clients \
    sshpass \
    iproute \
    iputils \
    lshw \
    NetworkManager \
    NetworkManager-tui
}

# ============================================================
# Ensure Python 3.11
# ============================================================
ensure_python_311() {
  if [ ! -x "$PYTHON_BIN" ]; then
    log "python3.11 not found at $PYTHON_BIN, installing OS packages..."
    install_os_packages
  else
    install_os_packages # still ensure other packages present
  fi

  if [ ! -x "$PYTHON_BIN" ]; then
    if command -v python3.11 >/dev/null 2>&1; then
      PYTHON_BIN="$(command -v python3.11)"
    fi
  fi

  if [ ! -x "$PYTHON_BIN" ]; then
    log "ERROR: python3.11 is REQUIRED but not available."
    exit 1
  fi
  log "Using Python interpreter: $PYTHON_BIN"
}

# ============================================================
# Python stack: pip, Ansible, netaddr, PyJWT
# ============================================================
install_python_stack() {
  ensure_python_311

  $PYTHON_BIN -m pip install --upgrade pip setuptools-rust wheel

  local ansible_spec="ansible"
  [ -n "$ANSIBLE_VERSION" ] && ansible_spec="ansible==${ANSIBLE_VERSION}"

  local netaddr_spec="netaddr"
  [ -n "$NETADDR_VERSION" ] && netaddr_spec="netaddr==${NETADDR_VERSION}"

  local pyjwt_spec="PyJWT"
  [ -n "$PYJWT_VERSION" ] && pyjwt_spec="PyJWT==${PYJWT_VERSION}"

  $PYTHON_BIN -m pip install \
    "$ansible_spec" \
    "$netaddr_spec" \
    "$pyjwt_spec"

  if ! command -v ansible-pull >/dev/null 2>&1; then
    log "ERROR: ansible-pull not found after Python stack installation."
    exit 1
  fi
}

# ============================================================
# Ansible collections required by ansible-pull-demo
# ============================================================
install_collections() {
  log "Installing Ansible collections required by ansible-pull-demo..."
  ansible-galaxy collection install \
    ansible.utils \
    ansible.netcommon \
    ansible.posix \
    community.crypto \
    community.general
}

# ============================================================
# Main
# ============================================================
main() {
  install_os_packages
  install_python_stack
  install_collections

  log "Bootstrap complete: node matches ansible-pull-demo requirements."
  log "Python: $PYTHON_BIN"
  log "Ansible version: $(ansible --version | head -n1 || echo 'unknown')"
}

main "$@"
