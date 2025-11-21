#!/bin/bash
set -euo pipefail

source "$HOME"/.bashrc

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

ARG_WORKDIR=${ARG_WORKDIR:-"$HOME"}
ARG_REPORT_TASKS=${ARG_REPORT_TASKS:-true}
ARG_MCP_APP_STATUS_SLUG=${ARG_MCP_APP_STATUS_SLUG:-}
ARG_OPENCODE_CONFIG=$(echo -n "${ARG_OPENCODE_CONFIG:-}" | base64 -d 2> /dev/null || echo "")
ARG_EXTERNAL_AUTH_ID=${ARG_EXTERNAL_AUTH_ID:-github}
ARG_OPENCODE_VERSION=${ARG_OPENCODE_VERSION:-latest}
ARG_INSTALL_METHOD=${ARG_INSTALL_METHOD:-npm}

install_nodejs() {
  if [ "$ARG_INSTALL_METHOD" != "npm" ]; then
    # curl install method doesn't need Node.js
    return 0
  fi

  if command_exists node; then
    echo "✓ Node.js $(node --version) already installed"
    return 0
  fi

  echo "Installing Node.js via NVM..."

  # Install NVM
  export NVM_DIR="$HOME/.nvm"
  if [ ! -d "$NVM_DIR" ]; then
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  fi

  # Load NVM
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

  # Install Node.js LTS
  echo "Installing Node.js LTS..."
  nvm install --lts
  nvm alias default node
  nvm use default

  echo "✓ Node.js $(node --version) installed successfully"
}

install_pnpm() {
  if [ "$ARG_INSTALL_METHOD" != "npm" ]; then
    return 0
  fi

  if command_exists pnpm; then
    echo "✓ pnpm $(pnpm --version) already installed"
    return 0
  fi

  echo "Installing pnpm..."
  npm install -g pnpm

  echo "✓ pnpm $(pnpm --version) installed successfully"
}

install_opencode() {
  if ! command_exists opencode; then
    echo "Installing OpenCode (version: ${ARG_OPENCODE_VERSION}, method: ${ARG_INSTALL_METHOD})..."

    if [ "$ARG_INSTALL_METHOD" = "curl" ]; then
      curl -fsSL https://opencode.ai/install | bash
    elif [ "$ARG_INSTALL_METHOD" = "npm" ]; then
      # Use pnpm for faster, more efficient installation
      if [ "$ARG_OPENCODE_VERSION" = "latest" ]; then
        pnpm install -g opencode-ai@latest
      else
        pnpm install -g "opencode-ai@${ARG_OPENCODE_VERSION}"
      fi
    else
      echo "ERROR: Unknown install method: $ARG_INSTALL_METHOD"
      exit 1
    fi

    if ! command_exists opencode; then
      echo "ERROR: Failed to install OpenCode"
      exit 1
    fi

    echo "✓ OpenCode installed successfully: $(opencode --version 2>&1 | head -1)"
  else
    echo "✓ OpenCode already installed: $(opencode --version 2>&1 | head -1)"
  fi
}

check_github_authentication() {
  echo "Checking GitHub authentication..."

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "✓ GitHub token provided via module configuration"
    return 0
  fi

  if command_exists coder; then
    if coder external-auth access-token "${ARG_EXTERNAL_AUTH_ID:-github}" > /dev/null 2>&1; then
      echo "✓ GitHub OAuth authentication via Coder external auth"
      return 0
    fi
  fi

  if command_exists gh && gh auth status > /dev/null 2>&1; then
    echo "✓ GitHub OAuth authentication via GitHub CLI"
    return 0
  fi

  echo "⚠ No GitHub authentication detected"
  echo "  OpenCode can still work with other providers"
  echo "  For GitHub Copilot support, configure GitHub external auth or run 'opencode auth login'"
  return 0
}

setup_opencode_configurations() {
  mkdir -p "$ARG_WORKDIR"

  local module_path="$HOME/.opencode-module"
  mkdir -p "$module_path"

  setup_opencode_config
}

setup_opencode_config() {
  export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  local opencode_data_dir="$XDG_DATA_HOME/opencode"
  local auth_file="$opencode_data_dir/auth.json"

  mkdir -p "$opencode_data_dir"

  if [ -n "$ARG_OPENCODE_CONFIG" ]; then
    echo "Setting up OpenCode configuration..."
    local opencode_config_dir="$HOME/.config/opencode"
    mkdir -p "$opencode_config_dir"
    echo "$ARG_OPENCODE_CONFIG" > "$opencode_config_dir/opencode.json"
  fi
}

configure_github_copilot_provider() {
  echo "Configuring GitHub Copilot provider for OpenCode..."

  export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  local opencode_data_dir="$XDG_DATA_HOME/opencode"
  local auth_file="$opencode_data_dir/auth.json"
  mkdir -p "$opencode_data_dir"

  local github_token=""

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    github_token="$GITHUB_TOKEN"
  elif command_exists coder; then
    github_token=$(coder external-auth access-token "${ARG_EXTERNAL_AUTH_ID:-github}" 2> /dev/null || echo "")
  fi

  if [ -n "$github_token" ] && [ "$github_token" != "null" ]; then
    echo "✓ GitHub token available - configuring Copilot provider in auth.json"

    # Create auth.json with GitHub Copilot credentials
    cat > "$auth_file" <<EOF
{
  "credentials": [
    {
      "provider": "copilot",
      "token": "$github_token"
    }
  ]
}
EOF

    echo "✓ GitHub Copilot provider configured successfully"
    export GITHUB_TOKEN="$github_token"
    export GH_TOKEN="$github_token"
  else
    echo "⚠ No GitHub token available."
    echo "  OpenCode can still work with other providers."
    echo "  To use GitHub Copilot, configure Coder external auth or run 'opencode auth login'"

    # Create empty auth.json if it doesn't exist
    if [ ! -f "$auth_file" ]; then
      echo '{"credentials":[]}' > "$auth_file"
    fi
  fi
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

install_nodejs
install_pnpm
install_opencode
check_github_authentication
setup_opencode_configurations
configure_github_copilot_provider
configure_coder_integration

echo "OpenCode module setup completed."
