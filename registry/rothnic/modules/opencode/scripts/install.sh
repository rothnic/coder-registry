#!/bin/bash
set -euo pipefail

# Load any existing PATH customizations
source "$HOME"/.bashrc 2>/dev/null || true

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

# ---------- ARGUMENTS / CONFIG ----------

ARG_WORKDIR=${ARG_WORKDIR:-"$HOME"}
ARG_REPORT_TASKS=${ARG_REPORT_TASKS:-true}
ARG_MCP_APP_STATUS_SLUG=${ARG_MCP_APP_STATUS_SLUG:-}
ARG_OPENCODE_CONFIG=$(echo -n "${ARG_OPENCODE_CONFIG:-}" | base64 -d 2> /dev/null || echo "")
ARG_EXTERNAL_AUTH_ID=${ARG_EXTERNAL_AUTH_ID:-github}
# Kept for future use, but NOT used in curl mode:
ARG_OPENCODE_VERSION=${ARG_OPENCODE_VERSION:-latest}
ARG_INSTALL_METHOD=${ARG_INSTALL_METHOD:-curl}

# ---------- OPENCODE INSTALL (CURL SCRIPT ONLY) ----------

install_opencode_via_curl() {
  if command_exists opencode; then
    echo "✓ OpenCode already installed: $(opencode --version 2>&1 | head -1 || echo '')"
    return 0
  fi

  echo "OpenCode not found on PATH. Installing via curl installer..."

  # Ensure it ends up in a predictable user bin dir
  mkdir -p "$HOME/.local/bin"
  export XDG_BIN_DIR="$HOME/.local/bin"

  # This installs the latest release and handles its own runtime
  curl -fsSL https://opencode.ai/install | bash

  # Make sure $HOME/.local/bin is on PATH in future shells
  if ! grep -q 'XDG_BIN_DIR="$HOME/.local/bin"' "$HOME/.bashrc" 2>/dev/null \
    && ! grep -q 'PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    {
      echo 'export XDG_BIN_DIR="$HOME/.local/bin"'
      echo 'export PATH="$HOME/.local/bin:$PATH"'
    } >> "$HOME/.bashrc"
  fi

  export PATH="$HOME/.local/bin:$PATH"

  if ! command_exists opencode; then
    echo "ERROR: OpenCode still not found after curl install."
    exit 1
  fi

  echo "✓ OpenCode installed via curl: $(opencode --version 2>&1 | head -1 || echo '')"
}

# ---------- GITHUB AUTH CHECK (for git/gh, NOT auth.json) ----------

check_github_authentication() {
  echo "Checking GitHub authentication for git/gh use (not Copilot tokens)..."

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "✓ GITHUB_TOKEN already set via environment/module"
    return 0
  fi

  if command_exists coder; then
    if coder external-auth access-token "${ARG_EXTERNAL_AUTH_ID:-github}" > /dev/null 2>&1; then
      local t
      t=$(coder external-auth access-token "${ARG_EXTERNAL_AUTH_ID:-github}" 2>/dev/null || echo "")
      if [ -n "$t" ] && [ "$t" != "null" ]; then
        export GITHUB_TOKEN="$t"
        export GH_TOKEN="$t"
        echo "✓ Using Coder external auth token for GitHub"
        return 0
      fi
    fi
  fi

  if command_exists gh && gh auth status > /dev/null 2>&1; then
    echo "✓ GitHub CLI OAuth authentication (gh auth status) is available"
    return 0
  fi

  echo "⚠ No GitHub authentication detected."
  echo "  This only affects Git operations / gh; OpenCode can still use other providers."
  return 0
}

# ---------- OPENCODE CONFIG (opencode.json, not auth.json) ----------

setup_opencode_configurations() {
  mkdir -p "$ARG_WORKDIR"

  local module_path="$HOME/.opencode-module"
  mkdir -p "$module_path"

  setup_opencode_config
}

setup_opencode_config() {
  export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  local opencode_data_dir="$XDG_DATA_HOME/opencode"

  mkdir -p "$opencode_data_dir"

  if [ -n "$ARG_OPENCODE_CONFIG" ]; then
    echo "Setting up OpenCode configuration (opencode.json)..."
    local opencode_config_dir="$HOME/.config/opencode"
    mkdir -p "$opencode_config_dir"
    echo "$ARG_OPENCODE_CONFIG" > "$opencode_config_dir/opencode.json"
  fi
}

# ---------- COPILOT / CODER INTEGRATION (NO auth.json FABRICATED) ----------

configure_github_copilot_provider() {
  # We do NOT fabricate auth.json here anymore.
  # It is provided verbatim via opencode_auth_config in start.sh.
  export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  local opencode_data_dir="$XDG_DATA_HOME/opencode"
  mkdir -p "$opencode_data_dir"

  echo "OpenCode auth.json will be provided via opencode_auth_config or created by 'opencode auth login'."
}

configure_coder_integration() {
  if [ "$ARG_REPORT_TASKS" = "true" ] && [ -n "$ARG_MCP_APP_STATUS_SLUG" ]; then
    echo "Configuring OpenCode task reporting..."
    export CODER_MCP_APP_STATUS_SLUG="$ARG_MCP_APP_STATUS_SLUG"
    export CODER_MCP_AI_AGENTAPI_URL="http://localhost:3284"
    echo "✓ Coder integration configured for task reporting"
  else
    echo "Task reporting disabled or no app status slug provided."
    export CODER_MCP_APP_STATUS_SLUG=""
    export CODER_MCP_AI_AGENTAPI_URL=""
  fi
}

# ---------- RUN IT ----------

install_opencode_via_curl
check_github_authentication
setup_opencode_configurations
configure_github_copilot_provider
configure_coder_integration

echo "OpenCode module setup completed."
