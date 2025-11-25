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

# This template requires a valid Docker socket
# You can reference Kubernetes/VM example templates and adapt:
# see: https://registry.coder.com/templates
provider "docker" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# OpenCode module handles automatic task reporting via agentapi
# For testing with current branch:
module "opencode" {
  count  = data.coder_workspace.me.start_count
  source = "git::https://github.com/coder/registry.git//registry/rothnic/modules/opencode?ref=claude/review-module-guidelines-014yytiyG8n6Rj4V8BbxZb2B"

  # After merge, use:
  # source  = "registry.coder.com/rothnic/opencode/coder"
  # version = "~> 1.0"

  agent_id  = coder_agent.main.id
  workdir   = "/home/coder/projects"
  order     = 999
  ai_prompt = data.coder_parameter.ai_prompt.value
  subdomain = true

  # GitHub Copilot Authentication:
  # 1. Run `opencode auth login` locally and select GitHub Copilot
  # 2. Copy ~/.local/share/opencode/auth.json to opencode-auth.json
  # 3. Uncomment the line below:
  # opencode_auth_config = file("${path.module}/opencode-auth.json")

  # Configure model (optional):
  # opencode_model = "claude-sonnet-4-20250514"

  # MCP Servers (optional):
  # mcp_servers = jsonencode({
  #   filesystem = {
  #     type    = "local"
  #     command = ["npx", "-y", "@anthropic/mcp-server-filesystem", "/home/coder/projects"]
  #   }
  # })
}

# Workspace presets for different use cases
# See https://coder.com/docs/admin/templates/extending-templates/parameters#workspace-presets
data "coder_workspace_preset" "default" {
  name    = "Default OpenCode Workspace"
  default = true
  parameters = {
    "system_prompt"   = <<-EOT
      You are a helpful coding assistant running inside a Coder workspace.
      Stay on track and feel free to debug, but when the original plan fails,
      do not choose a different route/architecture without checking the user first.
    EOT
    "container_image" = "codercom/enterprise-base:ubuntu"
  }
}

# Parameters (set via preset or manually)
data "coder_parameter" "ai_prompt" {
  type         = "string"
  name         = "AI Prompt"
  default      = ""
  description  = "Write a prompt for OpenCode"
  display_name = "AI Prompt"
  mutable      = true
}

data "coder_parameter" "system_prompt" {
  name         = "system_prompt"
  display_name = "System Prompt"
  type         = "string"
  form_type    = "textarea"
  description  = "System prompt for the agent with generalized instructions"
  mutable      = false
  default      = ""
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  type         = "string"
  default      = "codercom/enterprise-base:ubuntu"
  mutable      = false
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e
    # Prepare user home with default files on first start
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi
    # Create projects directory
    mkdir -p /home/coder/projects
  EOT

  # Git configuration from workspace owner
  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = data.coder_parameter.container_image.value
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name
  user     = "coder"
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
