#!/bin/bash
set -euo pipefail

source "$HOME"/.bashrc 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"

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
    echo "ERROR: OpenCode not found on PATH. Did install.sh fail?"
    exit 1
  fi
  echo "✓ OpenCode found: $(opencode --version 2>&1 | head -1 || echo '')"
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

setup_github_authentication() {
  export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  local opencode_data_dir="$XDG_DATA_HOME/opencode"
  local auth_file="$opencode_data_dir/auth.json"

  echo "Setting up OpenCode / GitHub authentication..."
  mkdir -p "$opencode_data_dir"

  # 1) If the module is given a full auth.json blob, use it verbatim.
  if [ -n "$ARG_OPENCODE_AUTH_CONFIG" ]; then
    echo "✓ Using pre-configured OpenCode auth.json from module variable"
    echo "$ARG_OPENCODE_AUTH_CONFIG" > "$auth_file"
  fi

  # 2) For general GitHub use (git, gh), try to populate GITHUB_TOKEN / GH_TOKEN.
  #    We do NOT derive auth.json from these tokens.
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    if command_exists coder; then
      local t
      t=$(coder external-auth access-token "${ARG_EXTERNAL_AUTH_ID:-github}" 2>/dev/null || echo "")
      if [ -n "$t" ] && [ "$t" != "null" ]; then
        export GITHUB_TOKEN="$t"
        export GH_TOKEN="$t"
        echo "✓ Using Coder external auth token for GitHub (GITHUB_TOKEN/GH_TOKEN)"
      fi
    fi
  else
    export GH_TOKEN="$GITHUB_TOKEN"
    echo "✓ Using GITHUB_TOKEN from module configuration"
  fi

  # 3) If still no token env, fall back to gh CLI if it's logged in.
  if [ -z "${GITHUB_TOKEN:-}" ] && command_exists gh && gh auth status >/dev/null 2>&1; then
    echo "✓ GitHub CLI auth is available (gh auth status ok)"
  fi

  # 4) If we still don't have an auth.json, warn, but don't fabricate one.
  if [ ! -f "$auth_file" ]; then
    echo "⚠ No OpenCode auth.json present."
    echo "  Copilot / provider credentials must be set by:"
    echo "    - Running 'opencode auth login' and wiring that auth.json into opencode_auth_config"
    echo "    - Or using another provider via env vars / config"
  fi
}

start_agentapi() {
  echo "Starting in directory: $ARG_WORKDIR"
  cd "$ARG_WORKDIR"

  echo "Starting OpenCode TUI with agentapi..."
  local initial_prompt
  initial_prompt=$(build_initial_prompt)

  # Run opencode with agentapi, backgrounded so start script returns quickly
  # The agentapi module's wrapper expects the script to exit so it can run its wait loop
  if [ -n "$initial_prompt" ]; then
    echo "Using initial prompt with system context"
    agentapi server -I="$initial_prompt" --type=opencode --term-width 67 --term-height 1190 -- opencode "$ARG_WORKDIR" &
  else
    agentapi server --type=opencode --term-width 67 --term-height 1190 -- opencode "$ARG_WORKDIR" &
  fi
}

setup_github_authentication
validate_opencode_installation
start_agentapi
