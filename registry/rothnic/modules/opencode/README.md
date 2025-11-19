---
display_name: OpenCode
description: AI-powered terminal coding agent with support for multiple providers including GitHub Copilot
icon: ../../../../.icons/code.svg
verified: false
tags: [agent, ai, opencode, coding-assistant, copilot]
---

# OpenCode

Run [OpenCode.ai](https://opencode.ai/) in your workspace for AI-powered coding assistance directly from the terminal. OpenCode is a powerful AI coding agent built for the terminal that supports multiple providers including GitHub Copilot, Anthropic, and OpenAI. This module integrates with [AgentAPI](https://github.com/coder/agentapi) for task reporting in the Coder UI.

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"
}
```

> [!IMPORTANT]
> This module assumes you have [Coder external authentication](https://coder.com/docs/admin/external-auth) configured with `id = "github"` if you want to use the GitHub Copilot provider. If not, you can provide a direct token using the `github_token` variable or configure authentication interactively using `opencode auth login`.

> [!NOTE]
> By default, this module is configured to run the embedded chat interface as a path-based application. In production, we recommend that you configure a [wildcard access URL](https://coder.com/docs/admin/setup#wildcard-access-url) and set `subdomain = true`. See [here](https://coder.com/docs/tutorials/best-practices/security-best-practices#disable-path-based-apps) for more details.

## Prerequisites

- **Node.js v18+** and **npm** (when using npm install method)
- **AI Provider Access** (depending on which provider you choose):
  - **GitHub Copilot**: Active [GitHub Copilot subscription](https://docs.github.com/en/copilot/about-github-copilot/subscription-plans-for-github-copilot)
  - **Anthropic**: Anthropic API key
  - **OpenAI**: OpenAI API key
- **GitHub authentication** (for Copilot provider) via one of:
  - [Coder external authentication](https://coder.com/docs/admin/external-auth) (recommended)
  - Direct token via `github_token` variable
  - Interactive login via `opencode auth login`

## Examples

### Basic Usage with GitHub Copilot

Use GitHub Copilot as the AI provider through Coder's external auth:

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"

  opencode_provider = "copilot"
}
```

### Usage with Tasks

For development environments where you want OpenCode to automatically resume sessions and receive initial prompts:

```tf
data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "AI Prompt"
  default     = ""
  description = "Initial task prompt for OpenCode."
  mutable     = true
}

module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"

  ai_prompt      = data.coder_parameter.ai_prompt.value
  resume_session = true
}
```

### Using Different AI Providers

OpenCode supports multiple AI providers. Configure the provider of your choice:

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"

  opencode_provider = "anthropic"  # or "openai", "copilot"

  # Provider credentials can be configured via opencode_config
  # or set up interactively with 'opencode auth login'
}
```

### Advanced Configuration

Customize OpenCode settings and installation:

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"

  # Version pinning (defaults to "latest")
  opencode_version = "0.1.5"

  # Installation method
  install_method = "npm"  # or "curl"

  # Custom OpenCode configuration
  opencode_config = jsonencode({
    theme = "dark"
    # Add other OpenCode config options
  })

  # Pre-install Node.js if needed
  pre_install_script = <<-EOT
    #!/bin/bash
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
  EOT
}
```

### Direct Token Authentication

Use this example when you want to provide a GitHub Personal Access Token for Copilot instead of using Coder external auth:

```tf
variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token"
  sensitive   = true
}

module "opencode" {
  source       = "registry.coder.com/rothnic/opencode/coder"
  version      = "1.0.0"
  agent_id     = coder_agent.example.id
  workdir      = "/home/coder/projects"
  github_token = var.github_token
}
```

### Standalone Mode

Run OpenCode as a command-line tool without task reporting or web interface. This installs and configures OpenCode, making it available as a CLI app in the Coder agent bar that you can launch to interact with OpenCode directly from your terminal. Set `report_tasks = false` to disable integration with Coder Tasks.

```tf
module "opencode" {
  source       = "registry.coder.com/rothnic/opencode/coder"
  version      = "1.0.0"
  agent_id     = coder_agent.example.id
  workdir      = "/home/coder"
  report_tasks = false
  cli_app      = true
}
```

## Authentication

The module supports multiple authentication methods for GitHub Copilot provider (in priority order):

1. **[Coder External Auth](https://coder.com/docs/admin/external-auth) (Recommended)** - Automatic if GitHub external auth is configured in Coder
2. **Direct Token** - Pass `github_token` variable (OAuth or Personal Access Token)
3. **Interactive** - Configure providers via `opencode auth login` command

For other providers (Anthropic, OpenAI), you can either:

- Use `opencode auth login` to configure interactively
- Configure via `opencode_config` variable
- Set environment variables in your template

> [!NOTE]
> OAuth tokens work best with GitHub Copilot. Personal Access Tokens may have limited functionality.

## Session Resumption

By default, the module resumes the latest OpenCode session when the workspace restarts. Set `resume_session = false` to always start fresh sessions.

> [!NOTE]
> Session resumption requires persistent storage for the home directory or workspace volume. Without persistent storage, sessions will not resume across workspace restarts.

## GitHub Copilot Integration

OpenCode can use GitHub Copilot as an AI provider, giving you access to powerful models like Claude Sonnet and GPT-4 through your GitHub Copilot subscription. To enable this:

1. Configure GitHub external auth in Coder (recommended) OR provide a GitHub token
2. Ensure you have an active GitHub Copilot subscription
3. Set `opencode_provider = "copilot"` (this is the default)

OpenCode will automatically authenticate with GitHub Copilot using your credentials. See the [OpenCode GitHub documentation](https://opencode.ai/docs/github/) for more details on GitHub Copilot integration.

## Troubleshooting

If you encounter any issues, check the log files in the `~/.opencode-module` directory within your workspace for detailed information.

```bash
# Installation logs
cat ~/.opencode-module/install.log

# Startup logs
cat ~/.opencode-module/agentapi-start.log

# Pre/post install script logs
cat ~/.opencode-module/pre_install.log
cat ~/.opencode-module/post_install.log
```

> [!NOTE]
> The `workdir` variable is required and specifies the directory where OpenCode will run.

## References

- [OpenCode.ai Documentation](https://opencode.ai/docs/)
- [OpenCode GitHub Repository](https://github.com/opencode-ai/opencode)
- [OpenCode GitHub Integration](https://opencode.ai/docs/github/)
- [AgentAPI Documentation](https://github.com/coder/agentapi)
- [Coder AI Agents Guide](https://coder.com/docs/tutorials/ai-agents)
