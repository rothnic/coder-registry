# Minimal OpenCode Agent Task Example
#
# This is a minimal template for testing the opencode module with agent tasks.
# Use this to test AI-driven coding workflows without additional tooling.
#
# Usage:
#   coder templates push opencode-test
#   coder create opencode-test --parameter git_repo="https://github.com/your/repo"
#   # Then use the OpenCode web app or CLI to interact with the agent

terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "coder" {}
provider "docker" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Optional: Git repo to clone for context
variable "git_repo" {
  description = "Git repository URL to clone (optional)"
  type        = string
  default     = ""
}

# Agent task for AI prompts
data "coder_parameter" "ai_prompt" {
  type         = "string"
  name         = "AI Prompt"
  default      = ""
  description  = "Prompt for the AI coding agent (used for agent tasks)"
  display_name = "AI Prompt"
  mutable      = true
}

data "coder_workspace_tags" "custom_workspace_tags" {
  tags = {
    "cluster" = "dev"
  }
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  dir  = "/workspace"

  display_apps {
    vscode          = false
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = true
  }
}

# OpenCode module from current branch
module "opencode" {
  # For testing with the current branch:
  source = "git::https://github.com/coder/registry.git//registry/rothnic/modules/opencode?ref=claude/review-module-guidelines-014yytiyG8n6Rj4V8BbxZb2B"

  # After merge, use:
  # source = "registry.coder.com/rothnic/opencode/coder"

  agent_id = coder_agent.main.id
  workdir  = "/workspace"

  # Enable web app access
  subdomain = true

  # Uncomment to configure a specific model:
  # opencode_model = "claude-sonnet-4-20250514"

  # Uncomment to add MCP servers:
  # mcp_servers = jsonencode({
  #   filesystem = {
  #     type    = "local"
  #     command = ["npx", "-y", "@anthropic/mcp-server-filesystem", "/workspace"]
  #   }
  # })
}

# Optional: Clone git repo for context
module "git_clone" {
  count    = var.git_repo != "" ? 1 : 0
  source   = "registry.coder.com/modules/git-clone/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  url      = var.git_repo
  path     = "/workspace"
}

resource "docker_image" "workspace" {
  name = "codercom/enterprise-base:ubuntu"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.workspace.image_id
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  hostname = data.coder_workspace.me.name
  command  = ["sh", "-c", coder_agent.main.init_script]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/workspace"
    volume_name    = docker_volume.workspace.name
    read_only      = false
  }
}

resource "docker_volume" "workspace" {
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  lifecycle {
    ignore_changes = all
  }
}
