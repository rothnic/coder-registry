#!/bin/bash
set -euo pipefail

source "$HOME"/.bashrc
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

  # Add provider if specified
  if [ -n "$ARG_OPENCODE_PROVIDER" ]; then
    OPENCODE_ARGS+=(--provider "$ARG_OPENCODE_PROVIDER")
  fi
}

setup_github_authentication() {
  export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  echo "Setting up GitHub authentication..."

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    export GH_TOKEN="$GITHUB_TOKEN"
    echo "✓ Using GitHub token from module configuration"
    return 0
  fi

  if command_exists coder; then
    local github_token
    if github_token=$(coder external-auth access-token "${ARG_EXTERNAL_AUTH_ID:-github}" 2> /dev/null); then
      if [ -n "$github_token" ] && [ "$github_token" != "null" ]; then
        export GITHUB_TOKEN="$github_token"
        export GH_TOKEN="$github_token"
        echo "✓ Using Coder external auth OAuth token"
        return 0
      fi
    fi
  fi

  if command_exists gh && gh auth status > /dev/null 2>&1; then
    echo "✓ Using GitHub CLI OAuth authentication"
    return 0
  fi

  echo "⚠ No GitHub authentication available"
  echo "  OpenCode can still work with other providers"
  echo "  Use 'opencode auth login' to configure providers"
  return 0
}

start_agentapi() {
  echo "Starting in directory: $ARG_WORKDIR"
  cd "$ARG_WORKDIR"

  build_opencode_args

  echo "Starting OpenCode with agentapi..."
  local initial_prompt
  initial_prompt=$(build_initial_prompt)

  # Use 'opencode acp' for Agent Communication Protocol mode
  # ACP mode is designed for stdio communication with agent wrappers like agentapi
  if [ -n "$initial_prompt" ]; then
    echo "Using initial prompt with system context"
    if [ ${#OPENCODE_ARGS[@]} -gt 0 ]; then
      echo "OpenCode arguments: ${OPENCODE_ARGS[*]}"
      agentapi server -I="$initial_prompt" --term-width 67 --term-height 1190 -- opencode acp "${OPENCODE_ARGS[@]}"
    else
      agentapi server -I="$initial_prompt" --term-width 67 --term-height 1190 -- opencode acp
    fi
  else
    if [ ${#OPENCODE_ARGS[@]} -gt 0 ]; then
      echo "OpenCode arguments: ${OPENCODE_ARGS[*]}"
      agentapi server --term-width 67 --term-height 1190 -- opencode acp "${OPENCODE_ARGS[@]}"
    else
      agentapi server --term-width 67 --term-height 1190 -- opencode acp
    fi
  fi
}

setup_github_authentication
validate_opencode_installation
start_agentapi
