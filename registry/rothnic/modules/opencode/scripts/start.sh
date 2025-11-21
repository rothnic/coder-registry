#!/bin/bash
set -euo pipefail

source "$HOME"/.bashrc 2>/dev/null || true

# Load NVM if available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Ensure pnpm is in PATH
export PATH="$HOME/.local/share/pnpm:$PATH"

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

ARG_WORKDIR=${ARG_WORKDIR:-"$HOME"}
ARG_AI_PROMPT=$(echo -n "${ARG_AI_PROMPT:-}" | base64 -d 2> /dev/null || echo "")
ARG_SYSTEM_PROMPT=$(echo -n "${ARG_SYSTEM_PROMPT:-}" | base64 -d 2> /dev/null || echo "")
ARG_EXTERNAL_AUTH_ID=${ARG_EXTERNAL_AUTH_ID:-github}
ARG_RESUME_SESSION=${ARG_RESUME_SESSION:-true}
ARG_OPENCODE_PROVIDER=${ARG_OPENCODE_PROVIDER:-copilot}
ARG_OPENCODE_AUTH_CONFIG=$(echo -n "${ARG_OPENCODE_AUTH_CONFIG:-}" | base64 -d 2> /dev/null || echo "")

validate_opencode_installation() {
  if ! command_exists opencode; then
    echo "ERROR: OpenCode not installed."
    exit 1
  fi
}

build_initial_prompt() {
  local initial_prompt=""

  if [ -n "$ARG_AI_PROMPT" ]; then
    if [ -n "$ARG_SYSTEM_PROMPT" ]; then
      initial_prompt="$ARG_SYSTEM_PROMPT

$ARG_AI_PROMPT"
    else
      initial_prompt="$ARG_AI_PROMPT"
    fi
  fi

  echo "$initial_prompt"
}

build_opencode_args() {
  OPENCODE_ARGS=()

  # ACP mode doesn't accept --provider argument
  # Provider is configured via auth.json during installation
}

setup_github_authentication() {
  export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  echo "Setting up GitHub authentication..."

  local opencode_data_dir="$XDG_DATA_HOME/opencode"
  local auth_file="$opencode_data_dir/auth.json"
  mkdir -p "$opencode_data_dir"

  # Check if pre-configured auth.json was provided
  if [ -n "$ARG_OPENCODE_AUTH_CONFIG" ]; then
    echo "✓ Using pre-configured auth.json from module variable"
    echo "$ARG_OPENCODE_AUTH_CONFIG" > "$auth_file"
    return 0
  fi

  # Try to get GitHub token from external auth
  local github_token=""

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    github_token="$GITHUB_TOKEN"
    echo "✓ Using GitHub token from module configuration"
  elif command_exists coder; then
    github_token=$(coder external-auth access-token "${ARG_EXTERNAL_AUTH_ID:-github}" 2> /dev/null || echo "")
    if [ -n "$github_token" ] && [ "$github_token" != "null" ]; then
      echo "✓ Using Coder external auth OAuth token"
    fi
  fi

  if [ -n "$github_token" ] && [ "$github_token" != "null" ]; then
    # Note: This creates a simplified auth.json that may not work with GitHub Copilot
    # For full GitHub Copilot support, use the opencode_auth_config variable
    echo "⚠ Warning: Using simplified auth format - GitHub Copilot may require device flow auth"
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
    export GITHUB_TOKEN="$github_token"
    export GH_TOKEN="$github_token"
    return 0
  fi

  if command_exists gh && gh auth status > /dev/null 2>&1; then
    echo "✓ Using GitHub CLI OAuth authentication"
    return 0
  fi

  echo "⚠ No GitHub authentication available"
  echo "  OpenCode can still work with other providers"
  echo "  To use GitHub Copilot:"
  echo "    1. Run 'opencode auth login' locally to get auth.json"
  echo "    2. Pass the auth.json content via opencode_auth_config variable"

  # Ensure auth.json exists even without credentials
  if [ ! -f "$auth_file" ]; then
    echo '{"credentials":[]}' > "$auth_file"
  fi

  return 0
}

start_agentapi() {
  echo "Starting in directory: $ARG_WORKDIR"
  cd "$ARG_WORKDIR"

  echo "Starting OpenCode TUI with agentapi..."
  local initial_prompt
  initial_prompt=$(build_initial_prompt)

  # Run opencode TUI with working directory as project path
  # Agentapi sends plain text to stdin/stdout, not JSON-RPC
  # OpenCode's TUI mode reads plain text input, similar to copilot/goose
  if [ -n "$initial_prompt" ]; then
    echo "Using initial prompt with system context"
    agentapi server -I="$initial_prompt" --type=opencode --term-width 67 --term-height 1190 -- opencode "$ARG_WORKDIR"
  else
    agentapi server --type=opencode --term-width 67 --term-height 1190 -- opencode "$ARG_WORKDIR"
  fi
}

setup_github_authentication
validate_opencode_installation
start_agentapi
