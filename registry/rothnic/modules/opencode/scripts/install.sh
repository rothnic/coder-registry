#!/bin/bash
set -euo pipefail

source "$HOME"/.bashrc

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

# Retry function for apt operations
retry_apt() {
  local max_attempts=5
  local attempt=1
  local delay=2

  while [ $attempt -le $max_attempts ]; do
    if "$@"; then
      return 0
    fi

    echo "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
    sleep $delay
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done

  echo "ERROR: Command failed after $max_attempts attempts: $*"
  return 1
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
    # curl install method includes Node.js, skip
    return 0
  fi

  if ! command_exists node; then
    echo "Node.js not found. Installing Node.js 20..."

    # Try to install using package manager
    if command_exists apt-get; then
      echo "Installing Node.js via apt-get..."

      # Wait for any existing apt processes to finish
      local wait_count=0
      while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
            sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        if [ $wait_count -ge 30 ]; then
          echo "WARNING: Waited 30s for apt lock, proceeding anyway..."
          break
        fi
        echo "Waiting for other apt processes to finish..."
        sleep 1
        wait_count=$((wait_count + 1))
      done

      # Add NodeSource repository with retries
      retry_apt bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"

      # Install Node.js with retries
      retry_apt sudo apt-get install -y nodejs
    elif command_exists yum; then
      echo "Installing Node.js via yum..."
      retry_apt bash -c "curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -"
      retry_apt sudo yum install -y nodejs
    elif command_exists apk; then
      echo "Installing Node.js via apk..."
      retry_apt sudo apk add --no-cache nodejs npm
    else
      echo "WARNING: Could not detect package manager. Attempting to install via nvm..."
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      nvm install 20
      nvm use 20
    fi

    # Reload shell environment
    source "$HOME"/.bashrc 2> /dev/null || true

    if ! command_exists node; then
      echo "ERROR: Failed to install Node.js"
      exit 1
    fi

    echo "✓ Node.js installed successfully: $(node --version)"
  else
    node_version=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$node_version" -lt 18 ]; then
      echo "WARNING: Node.js v$node_version detected. OpenCode requires v18+. Attempting upgrade..."
      # Attempt to upgrade (best effort)
      if command_exists apt-get; then
        retry_apt bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
        retry_apt sudo apt-get install -y nodejs
      fi
    else
      echo "✓ Node.js $(node --version) already installed"
    fi
  fi
}

install_opencode() {
  if ! command_exists opencode; then
    echo "Installing OpenCode (version: ${ARG_OPENCODE_VERSION}, method: ${ARG_INSTALL_METHOD})..."

    if [ "$ARG_INSTALL_METHOD" = "curl" ]; then
      curl -fsSL https://opencode.ai/install | bash
    elif [ "$ARG_INSTALL_METHOD" = "npm" ]; then
      # Configure npm to install to user directory to avoid permission issues
      mkdir -p "$HOME/.local/bin"
      npm config set prefix "$HOME/.local"
      export PATH="$HOME/.local/bin:$PATH"

      # Persist PATH to shell profile
      if ! grep -q 'PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2> /dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
      fi

      if [ "$ARG_OPENCODE_VERSION" = "latest" ]; then
        npm install -g opencode-ai@latest
      else
        npm install -g "opencode-ai@${ARG_OPENCODE_VERSION}"
      fi
    else
      echo "ERROR: Unknown install method: $ARG_INSTALL_METHOD"
      exit 1
    fi

    # Reload shell to get opencode in PATH
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
    cat > "$auth_file" << EOF
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
install_opencode
check_github_authentication
setup_opencode_configurations
configure_github_copilot_provider
configure_coder_integration

echo "OpenCode module setup completed."
