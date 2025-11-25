---
display_name: OpenCode
description: AI-powered terminal coding agent with support for GitHub Copilot, Anthropic, and OpenAI
icon: ../../../../.icons/code.svg
maintainer_github: rothnic
verified: false
tags: [agent, ai, opencode, coding-assistant, copilot, terminal]
---

# OpenCode

Integrate [OpenCode.ai](https://opencode.ai/) - an AI coding agent that executes tasks in your terminal and reports progress to Coder's task system via [AgentAPI](https://github.com/coder/agentapi). Supports GitHub Copilot, Anthropic Claude, OpenAI, and other providers.

## Quick Start

**Basic setup:**

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  agent_id = coder_agent.main.id
  workdir  = "/home/coder"
}
```

**With Coder Tasks (recommended for AI workspaces):**

```tf
data "coder_task" "me" {}

module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  agent_id = coder_agent.main.id
  workdir  = "/home/coder"

  ai_prompt    = data.coder_task.me.prompt
  report_tasks = true
}
```

**With model and MCP servers:**

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  agent_id = coder_agent.main.id
  workdir  = "/home/coder"

  opencode_model = "claude-3.7-sonnet"
  mcp_servers = jsonencode({
    filesystem = {
      type    = "local"
      command = ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/coder"]
    }
  })
}
```

## Authentication

OpenCode supports many AI providers (GitHub Copilot, Anthropic Claude, OpenAI, etc.). Authentication is managed via `~/.local/share/opencode/auth.json`, created by running `opencode auth login`.

### GitHub Copilot

GitHub Copilot requires OAuth device flow authentication - you cannot use standard GitHub tokens.

**Option 1: Pre-configured auth (recommended for automation)**

Generate auth on your local machine, then embed in your template:

```bash
# On your local machine
npm install -g opencode-ai
opencode auth login                   # Select "GitHub Copilot", complete device flow
cat ~/.local/share/opencode/auth.json # Copy this content
```

Create `opencode-auth.json` in your template directory, then reference it:

```tf
module "opencode" {
  source               = "registry.coder.com/rothnic/opencode/coder"
  agent_id             = coder_agent.main.id
  workdir              = "/workspaces"
  opencode_auth_config = file("${path.module}/opencode-auth.json")
}
```

**Option 2: Manual login per workspace**

Users run `opencode auth login` inside the workspace. Auth persists across restarts.

### Other Providers (Claude, OpenAI, etc.)

For Anthropic, OpenAI, DeepSeek, Groq, and [other providers](https://opencode.ai/docs/providers/):

1. Users run `opencode auth login` in the workspace
2. Select their provider and enter API key
3. Credentials persist in `~/.local/share/opencode/auth.json`

Or provide API keys via environment variables (see provider docs).

**Note:** The `opencode_provider` variable is for documentation only - it doesn't configure OpenCode. Provider selection happens via `opencode auth login`.

## Configuration

### Core Variables

| Variable   | Description                    | Default | Required |
| ---------- | ------------------------------ | ------- | -------- |
| `agent_id` | Coder agent ID                 | -       | Yes      |
| `workdir`  | Working directory for OpenCode | -       | Yes      |

### Authentication & Provider

| Variable               | Description                                                                            | Default     |
| ---------------------- | -------------------------------------------------------------------------------------- | ----------- |
| `opencode_auth_config` | Pre-configured auth.json content (for GitHub Copilot or any provider)                  | `""`        |
| `opencode_provider`    | Intended provider (documentation only - actual provider set via `opencode auth login`) | `"copilot"` |
| `github_token`         | GitHub token for git operations (not AI provider auth)                                 | `""`        |
| `external_auth_id`     | Coder external auth provider ID for git operations                                     | `"github"`  |

### Task Integration

| Variable         | Description                                           | Default         |
| ---------------- | ----------------------------------------------------- | --------------- |
| `ai_prompt`      | Initial task prompt (use `data.coder_task.me.prompt`) | `""`            |
| `system_prompt`  | Custom system prompt for the AI                       | Built-in prompt |
| `report_tasks`   | Enable task reporting to Coder UI                     | `true`          |
| `resume_session` | Auto-resume latest session on restart                 | `true`          |

### Installation & Versioning

| Variable           | Description                                     | Default     |
| ------------------ | ----------------------------------------------- | ----------- |
| `opencode_version` | OpenCode version (`latest` or specific version) | `"latest"`  |
| `install_method`   | Installation method (`npm` recommended)         | `"npm"`     |
| `install_agentapi` | Install AgentAPI                                | `true`      |
| `agentapi_version` | AgentAPI version                                | `"v0.10.0"` |

### UI & Apps

| Variable               | Description                                                                | Default            |
| ---------------------- | -------------------------------------------------------------------------- | ------------------ |
| `web_app_display_name` | Display name in Coder UI                                                   | `"OpenCode"`       |
| `order`                | App position in UI                                                         | `null`             |
| `group`                | App group name                                                             | `null`             |
| `icon`                 | App icon path                                                              | `"/icon/code.svg"` |
| `subdomain`            | Use subdomain for app access (requires [wildcard DNS][wildcard-dns-setup]) | `false`            |
| `cli_app`              | Create CLI app entry                                                       | `false`            |

[wildcard-dns-setup]: https://coder.com/docs/admin/setup#wildcard-access-url

### Model & MCP Configuration

| Variable         | Description                                                                          | Default |
| ---------------- | ------------------------------------------------------------------------------------ | ------- |
| `opencode_model` | Model to use (e.g., `claude-3.7-sonnet`, `gpt-4o`). If empty, uses provider default. | `""`    |
| `mcp_servers`    | MCP servers configuration as JSON string (see example below)                         | `""`    |

**MCP Servers Example:**

OpenCode uses `type: "local"` for local MCP servers with `command` as an array (including all arguments):

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  agent_id = coder_agent.main.id
  workdir  = "/workspaces"

  opencode_model = "claude-3.7-sonnet"

  mcp_servers = jsonencode({
    filesystem = {
      type    = "local"
      command = ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/workspaces"]
    }
    github = {
      type    = "local"
      command = ["npx", "-y", "@modelcontextprotocol/server-github"]
      environment = {
        GITHUB_TOKEN = var.github_token
      }
    }
  })
}
```

For remote MCP servers, use `type: "remote"` with a `url`:

```tf
mcp_servers = jsonencode({
  context7 = {
    type = "remote"
    url  = "https://mcp.context7.com/mcp"
  }
})
```

See [OpenCode MCP documentation](https://opencode.ai/docs/mcp-servers/) for more details.

### Advanced

| Variable              | Description                                                         | Default |
| --------------------- | ------------------------------------------------------------------- | ------- |
| `opencode_config`     | Full custom OpenCode config (JSON). Overrides other config options. | `""`    |
| `pre_install_script`  | Script to run before install                                        | `null`  |
| `post_install_script` | Script to run after install                                         | `null`  |

See [main.tf](./main.tf) for complete variable definitions.

## Features

- 🤖 Multiple AI providers (Copilot, Claude, GPT)
- 🔧 MCP servers configuration support
- 🎯 Model selection per deployment
- 📊 Task reporting to Coder UI
- 💾 Session persistence
- 🔐 Flexible authentication
- 🚀 Node.js tarball installation (no apt/nvm)
- 📌 Version pinning support via `opencode_version`
- 💾 Shared Node.js cache across workspaces

## Complete Template Example

Here's a lightweight template for Coder task execution:

```tf
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

provider "docker" {}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Task data source - provides prompts from Coder Tasks UI
data "coder_task" "me" {}

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  startup_script = <<-EOT
    set -e
    mkdir -p /workspaces
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }
}

# OpenCode AI coding agent
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  agent_id = coder_agent.main.id
  workdir  = "/workspaces"

  # Pre-configured authentication (from 'opencode auth login' output)
  opencode_auth_config = file("${path.module}/opencode-auth.json")

  # Pass task prompt from Coder Tasks UI
  ai_prompt = data.coder_task.me.prompt

  # Enable task reporting for Coder UI integration
  report_tasks = true

  # Use subdomain for better app routing (requires wildcard DNS)
  # subdomain = true

  # Display settings
  order                = 1
  web_app_display_name = "OpenCode AI"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = "codercom/enterprise-base:ubuntu"
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  entrypoint = ["sh", "-c", coder_agent.main.init_script]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
}
```

## Prerequisites

- None - Node.js 20 is automatically installed via tarball

## Notes

- **Node.js installation**: Installed via tarball (not apt/nvm) to `/workspaces/.coder-tools` for reliability and workspace portability
- **OpenCode installation**: Installed via `npm install -g opencode-ai@{version}`
- **Caching**: Node.js and npm cache shared across workspaces in `/workspaces/.coder-tools`
- **Version pinning**: Use `opencode_version` variable to lock to specific versions
- **TUI limitations**: Some interactive features (slash commands, menus) may have limitations through AgentAPI
- **Subdomain access**: For production, use `subdomain = true` with [wildcard access URL](https://coder.com/docs/admin/setup#wildcard-access-url)
- **Task reporting**: When `report_tasks = true`, the module automatically configures system prompts for granular task status updates

## Resources

- [OpenCode Documentation](https://opencode.ai/docs/)
- [OpenCode GitHub](https://github.com/opencode-ai/opencode)
- [AgentAPI](https://github.com/coder/agentapi)
