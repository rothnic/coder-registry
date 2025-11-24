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
ARG_MCP_SERVERS=$(echo -n "${ARG_MCP_SERVERS:-}" | base64 -d 2> /dev/null || echo "")
ARG_OPENCODE_MODEL=${ARG_OPENCODE_MODEL:-}
ARG_EXTERNAL_AUTH_ID=${ARG_EXTERNAL_AUTH_ID:-github}
ARG_OPENCODE_VERSION=${ARG_OPENCODE_VERSION:-latest}
ARG_INSTALL_METHOD=${ARG_INSTALL_METHOD:-npm}

# Version pins for the toolchain
NODE_VERSION="${NODE_VERSION:-20.18.0}"

# ---------- NODE INSTALL (NO APT/NVM, SHARED CACHE) ----------

install_nodejs() {
  if [ "$ARG_INSTALL_METHOD" != "npm" ]; then
    echo "ERROR: install_method=${ARG_INSTALL_METHOD} is not supported without the curl installer."
    echo "       Use install_method=\"npm\" in the module or Terraform."
    exit 1
  fi

  # Shared tool root across workspaces on this host
  local dev_root="${DEV_ROOT:-/workspaces}"
  local tool_root="${TOOL_ROOT:-$dev_root/.coder-tools}"
  local node_distro="linux-x64"
  local node_tarball="node-v${NODE_VERSION}-${node_distro}.tar.xz"
  local node_dir="${tool_root}/node-v${NODE_VERSION}-${node_distro}"

  mkdir -p "$tool_root"

  if [ ! -d "$node_dir" ]; then
    echo "Node.js ${NODE_VERSION} not found in cache. Downloading to ${tool_root}..."
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${node_tarball}" \
      -o "${tool_root}/${node_tarball}"

    echo "Extracting Node.js..."
    tar -xJf "${tool_root}/${node_tarball}" -C "$tool_root"
    rm -f "${tool_root}/${node_tarball}"
  else
    echo "✓ Node.js ${NODE_VERSION} already cached at ${node_dir}"
  fi

  # Make Node available now
  export PATH="${node_dir}/bin:$HOME/.local/bin:$PATH"

  # Shared npm cache to speed up repeated installs
  local npm_cache_dir="${tool_root}/npm-cache"
  mkdir -p "$npm_cache_dir"
  export NPM_CONFIG_CACHE="$npm_cache_dir"

  # Persist PATH + npm cache so start.sh and future shells see it
  if ! grep -q "node-v${NODE_VERSION}-${node_distro}/bin" "$HOME/.bashrc" 2>/dev/null; then
    {
      echo "export PATH=\"${node_dir}/bin:\$HOME/.local/bin:\$PATH\""
      echo "export NPM_CONFIG_CACHE=\"${npm_cache_dir}\""
    } >> "$HOME/.bashrc"
  fi

  if ! command_exists node; then
    echo "ERROR: Node.js still not on PATH after tarball install"
    exit 1
  fi

  echo "✓ Node.js installed via tarball: $(node --version)"
}

# ---------- OPENCODE INSTALL (NPM, PINNABLE VERSION) ----------

install_opencode() {
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

  if ! command_exists opencode; then
    echo "Installing OpenCode via npm (version: ${ARG_OPENCODE_VERSION})..."

    npm config set prefix "$HOME/.local" >/dev/null 2>&1 || true

    if ! grep -q 'PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi

    if [ "$ARG_OPENCODE_VERSION" = "latest" ]; then
      npm install -g opencode-ai@latest
    else
      npm install -g "opencode-ai@${ARG_OPENCODE_VERSION}"
    fi

    export PATH="$HOME/.local/bin:$PATH"

    if ! command_exists opencode; then
      echo "ERROR: Failed to install OpenCode"
      exit 1
    fi

    echo "✓ OpenCode installed successfully: $(opencode --version 2>&1 | head -1)"
  else
    echo "✓ OpenCode already installed: $(opencode --version 2>&1 | head -1)"
  fi
}

# ---------- GITHUB AUTH (for git/gh, NOT auth.json) ----------

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
  local opencode_config_dir="$HOME/.config/opencode"

  mkdir -p "$opencode_data_dir"
  mkdir -p "$opencode_config_dir"

  # If full custom config provided, use it directly
  if [ -n "$ARG_OPENCODE_CONFIG" ]; then
    echo "Setting up OpenCode configuration (opencode.json) from custom config..."
    echo "$ARG_OPENCODE_CONFIG" > "$opencode_config_dir/opencode.json"
    return 0
  fi

  # Otherwise, build config from individual options
  echo "Building OpenCode configuration..."

  # Start with base config
  local config='{}'

  # Add model config if specified
  if [ -n "$ARG_OPENCODE_MODEL" ]; then
    echo "  Adding model configuration: $ARG_OPENCODE_MODEL"
    config=$(echo "$config" | jq --arg model "$ARG_OPENCODE_MODEL" '. + {
      "agents": {
        "coder": {"model": $model},
        "task": {"model": $model}
      }
    }')
  fi

  # Add MCP servers if specified
  if [ -n "$ARG_MCP_SERVERS" ]; then
    echo "  Adding MCP servers configuration..."
    # Merge MCP servers into config
    local mcp_config
    mcp_config=$(echo "$ARG_MCP_SERVERS" | jq '.')
    if [ $? -eq 0 ] && [ -n "$mcp_config" ]; then
      config=$(echo "$config" | jq --argjson mcp "$mcp_config" '. + {"mcpServers": $mcp}')
    else
      echo "  ⚠ Warning: Invalid MCP servers JSON, skipping"
    fi
  fi

  # Only write config if we have something to configure
  if [ "$config" != '{}' ]; then
    echo "$config" | jq '.' > "$opencode_config_dir/opencode.json"
    echo "✓ OpenCode config written to $opencode_config_dir/opencode.json"
  else
    echo "  No custom configuration needed"
  fi
}

# ---------- COPILOT / CODER INTEGRATION (NO auth.json FABRICATED) ----------

configure_github_copilot_provider() {
  # We do NOT fabricate auth.json here anymore.
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

install_nodejs
install_opencode
check_github_authentication
setup_opencode_configurations
configure_github_copilot_provider
configure_coder_integration

echo "OpenCode module setup completed."
