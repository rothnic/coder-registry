---
display_name: OpenCode
description: AI-powered terminal coding agent with support for GitHub Copilot, Anthropic, and OpenAI
icon: ../../../../.icons/code.svg
maintainer_github: rothnic
verified: false
tags: [agent, ai, opencode, coding-assistant, copilot, terminal]
---

# OpenCode

Integrate [OpenCode.ai](https://opencode.ai/) - an AI coding agent that runs in your terminal and integrates with Coder's task system via [AgentAPI](https://github.com/coder/agentapi).

## Quick Start

```tf
module "opencode" {
  source  = "git::https://github.com/rothnic/coder-registry.git//registry/rothnic/modules/opencode"

  agent_id = coder_agent.main.id
  workdir  = "/workspaces"
}
```

Node.js LTS is automatically installed via NVM when using the `npm` install method (default). The module also installs pnpm for faster package management.

## Authentication (Optional)

### GitHub Copilot

OpenCode requires GitHub Copilot's special session token format. Three options:

**Option 1: Pre-configured auth (Recommended)**

Run locally:
```bash
npm install -g opencode-ai
opencode auth login  # Complete device flow
cat ~/.local/share/opencode/auth.json  # Copy this
```

In your template:
```tf
module "opencode" {
  source = "..."

  opencode_auth_config = file("${path.module}/opencode-auth.json")  # Store as file
  # Or use variable: opencode_auth_config = var.opencode_auth_json
}
```

**Option 2: Coder external auth (May not work)**

Configure [external auth](https://coder.com/docs/admin/external-auth) with `id = "github"`. Note: Regular OAuth tokens may not work with Copilot's authentication.

**Option 3: Manual login**

Users run `opencode auth login` in the workspace. Auth persists across restarts.

### Other Providers

For Anthropic, OpenAI, etc., users authenticate via `opencode auth login` in the workspace.

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `agent_id` | Coder agent ID | Required |
| `workdir` | Working directory | Required |
| `opencode_auth_config` | Pre-configured auth.json content | `""` (optional) |
| `opencode_version` | OpenCode version | `"latest"` |
| `install_method` | Installation method: `npm` or `curl` | `"npm"` |
| `report_tasks` | Enable Coder task reporting | `true` |
| `subdomain` | Use subdomain for app access | `false` |

See [variables](./main.tf) for complete list.

## Features

- 🤖 Multiple AI providers (Copilot, Claude, GPT)
- 📊 Task reporting to Coder UI
- 💾 Session persistence
- 🔐 Flexible authentication
- 🚀 Automatic Node.js installation via NVM
- ⚡ Fast package management with pnpm

## Prerequisites

- **Node.js 18+**: Automatically installed via NVM (npm install method only)
- **pnpm**: Automatically installed for faster package management

## Notes

- Node.js LTS is automatically installed via NVM (if using npm install method)
- Uses pnpm for faster, more efficient package installation
- TUI may have limitations through AgentAPI (slash commands, menus)
- For production, use `subdomain = true` with [wildcard access URL](https://coder.com/docs/admin/setup#wildcard-access-url)

## Resources

- [OpenCode Documentation](https://opencode.ai/docs/)
- [OpenCode GitHub](https://github.com/opencode-ai/opencode)
- [AgentAPI](https://github.com/coder/agentapi)
