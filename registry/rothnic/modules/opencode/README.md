---
display_name: OpenCode
description: AI-powered terminal coding agent with support for multiple providers including GitHub Copilot, Anthropic, and OpenAI
icon: ../../../../.icons/code.svg
maintainer_github: rothnic
verified: false
tags: [agent, ai, opencode, coding-assistant, copilot, terminal, automation]
---

# OpenCode

Integrate [OpenCode.ai](https://opencode.ai/) into your Coder workspace for AI-powered coding assistance directly from the terminal. OpenCode is a powerful, open-source AI coding agent built specifically for the terminal that brings the power of AI pair programming to your command line.

## What is OpenCode?

[OpenCode](https://github.com/opencode-ai/opencode) is an AI coding agent that runs in your terminal and helps you:

- **Write code faster** with intelligent completions and suggestions
- **Debug issues** with AI-powered error analysis and fixes
- **Refactor code** with automated improvements and best practices
- **Learn new technologies** with contextual explanations and examples
- **Automate tasks** through natural language instructions

Unlike traditional IDEs with AI extensions, OpenCode is designed for terminal-first workflows and integrates seamlessly with your existing command-line tools.

## Key Features

- 🤖 **Multiple AI Providers**: Choose from GitHub Copilot, Anthropic Claude, OpenAI GPT, and more
- 🔐 **Seamless Authentication**: Automatic GitHub authentication via Coder external auth
- 📊 **Task Reporting**: Integration with [AgentAPI](https://github.com/coder/agentapi) for real-time task tracking in Coder UI
- 💾 **Session Persistence**: Resume your AI conversations across workspace restarts
- 🎨 **Customizable**: Configure prompts, providers, and behavior to match your workflow
- 🚀 **Multiple Installation Methods**: NPM or direct curl installation

## Quick Start

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"
}
```

This basic configuration installs OpenCode with GitHub Copilot as the default provider and enables task reporting to your Coder UI.

> [!IMPORTANT]
> For GitHub Copilot integration, ensure you have [Coder external authentication](https://coder.com/docs/admin/external-auth) configured with `id = "github"`. Alternatively, provide a token via the `github_token` variable or configure authentication interactively with `opencode auth login`.

> [!NOTE]
> By default, this module uses path-based app access. In production, we recommend configuring a [wildcard access URL](https://coder.com/docs/admin/setup#wildcard-access-url) and setting `subdomain = true`. See [security best practices](https://coder.com/docs/tutorials/best-practices/security-best-practices#disable-path-based-apps) for details.

## Prerequisites

- **Node.js v18+** and **npm** (when using npm install method)
- **AI Provider Access** (one of the following):
  - **[GitHub Copilot](https://github.com/features/copilot)**: Active subscription (Individual, Pro, Business, or Enterprise)
  - **[Anthropic](https://www.anthropic.com/)**: API key for Claude models
  - **[OpenAI](https://platform.openai.com/)**: API key for GPT models
- **GitHub Authentication** (for Copilot provider):
  - [Coder external authentication](https://coder.com/docs/admin/external-auth) (recommended)
  - Direct token via `github_token` variable
  - Interactive login via `opencode auth login`

## Usage Examples

### Basic GitHub Copilot Setup

The simplest way to get started with GitHub Copilot:

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"

  opencode_provider = "copilot"
}
```

### Task-Based Workflow

Enable initial prompts and task tracking for automated workflows:

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

### Multiple AI Providers

Switch between different AI providers based on your needs:

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"

  # Choose your provider: "copilot", "anthropic", "openai", etc.
  opencode_provider = "anthropic"

  # Configure provider credentials via opencode_config
  # or set up interactively with 'opencode auth login'
}
```

### Advanced Configuration

Full customization with version pinning and pre-installation scripts:

```tf
module "opencode" {
  source   = "registry.coder.com/rothnic/opencode/coder"
  version  = "1.0.0"
  agent_id = coder_agent.example.id
  workdir  = "/home/coder/projects"

  # Pin OpenCode version for stability
  opencode_version = "0.1.5"

  # Choose installation method
  install_method = "npm"  # or "curl"

  # Custom configuration
  opencode_config = jsonencode({
    theme = "dark"
    # Additional OpenCode config options
  })

  # Ensure Node.js is available
  pre_install_script = <<-EOT
    #!/bin/bash
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
  EOT
}
```

### Direct Token Authentication

Provide a GitHub token directly instead of using Coder external auth:

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

### Standalone CLI Mode

Install OpenCode as a standalone CLI tool without the web interface:

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

This makes OpenCode available as a CLI app in your Coder agent bar for direct terminal access.

## Authentication

### GitHub Copilot Provider

The module supports multiple authentication methods (in priority order):

1. **[Coder External Auth](https://coder.com/docs/admin/external-auth) (Recommended)**
   - Automatic OAuth token retrieval
   - Best security and user experience
   - Configured at the Coder deployment level

2. **Direct Token**
   - Pass via `github_token` variable
   - Supports OAuth or Personal Access Tokens
   - Good for testing or specific use cases

3. **Interactive Login**
   - Run `opencode auth login` in the workspace
   - Manual configuration of providers
   - Useful for multiple provider setups

### Other Providers

For Anthropic, OpenAI, and other providers:

- Use `opencode auth login` to configure interactively
- Set via `opencode_config` variable with API keys
- Configure through environment variables in your template

> [!NOTE]
> OAuth tokens work best with GitHub Copilot. Personal Access Tokens may have limited functionality depending on permissions.

## Session Management

OpenCode supports persistent sessions that survive workspace restarts:

- **Default behavior**: Automatically resumes the latest session
- **Disable resumption**: Set `resume_session = false` for fresh sessions
- **Requirements**: Persistent storage for home directory or workspace volume

```tf
module "opencode" {
  source         = "registry.coder.com/rothnic/opencode/coder"
  version        = "1.0.0"
  agent_id       = coder_agent.example.id
  workdir        = "/home/coder/projects"
  resume_session = false  # Always start fresh
}
```

> [!NOTE]
> Without persistent storage, sessions cannot resume across workspace restarts, and you'll start fresh each time.

## GitHub Copilot Integration

OpenCode leverages GitHub Copilot to provide access to powerful AI models including:

- **Claude Sonnet 4** and **Claude Sonnet 4.5**
- **GPT-4** and **GPT-5**
- Other models available through your GitHub Copilot subscription

### Setup Steps

1. **Configure Authentication**
   - Set up [Coder external auth](https://coder.com/docs/admin/external-auth) for GitHub, OR
   - Provide a GitHub token via `github_token` variable

2. **Verify Copilot Subscription**
   - Ensure you have an active [GitHub Copilot subscription](https://docs.github.com/en/copilot/about-github-copilot/subscription-plans-for-github-copilot)
   - Individual, Pro+, Business, or Enterprise plans supported

3. **Use Copilot Provider**
   - Set `opencode_provider = "copilot"` (default)
   - OpenCode automatically authenticates using your credentials

For more details, see the [OpenCode GitHub Integration documentation](https://opencode.ai/docs/github/).

## Troubleshooting

### Check Installation Logs

All logs are stored in `~/.opencode-module/` within your workspace:

```bash
# Installation logs
cat ~/.opencode-module/install.log

# Startup logs
cat ~/.opencode-module/agentapi-start.log

# Pre/post install script logs
cat ~/.opencode-module/pre_install.log
cat ~/.opencode-module/post_install.log
```

### Common Issues

**OpenCode not found after installation**
```bash
# Check if OpenCode is in PATH
which opencode

# Verify installation
opencode --version

# Reload shell
source ~/.bashrc
```

**GitHub authentication fails**
```bash
# Check Coder external auth
coder external-auth access-token github

# Manually configure
opencode auth login
```

**Node.js version too old**
```bash
# Check Node version
node --version

# Install Node.js 20+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `agent_id` | string | (required) | The ID of the Coder agent |
| `workdir` | string | (required) | Working directory for OpenCode |
| `opencode_provider` | string | `"copilot"` | AI provider to use |
| `github_token` | string | `""` | GitHub token for authentication |
| `opencode_version` | string | `"latest"` | OpenCode version to install |
| `install_method` | string | `"npm"` | Installation method: npm or curl |
| `report_tasks` | bool | `true` | Enable task reporting to Coder UI |
| `resume_session` | bool | `true` | Resume sessions on restart |
| `subdomain` | bool | `false` | Use subdomain for AgentAPI |
| `cli_app` | bool | `false` | Create CLI app in agent bar |

See the full list of variables in [main.tf](./main.tf).

## Learn More

- 📚 [OpenCode Documentation](https://opencode.ai/docs/)
- 🐙 [OpenCode GitHub Repository](https://github.com/opencode-ai/opencode)
- 🔗 [OpenCode GitHub Integration](https://opencode.ai/docs/github/)
- 🔌 [OpenCode Providers](https://opencode.ai/docs/providers/)
- 🤖 [AgentAPI Documentation](https://github.com/coder/agentapi)
- 📖 [Coder AI Agents Guide](https://coder.com/docs/tutorials/ai-agents)

## Support

For issues specific to this module, please [open an issue](https://github.com/rothnic/coder-registry/issues) in the repository.

For OpenCode-related questions, visit the [OpenCode GitHub Discussions](https://github.com/opencode-ai/opencode/discussions).

---

**Maintained by** [Nick Roth](https://github.com/rothnic) | [Website](https://www.nickroth.com) | [LinkedIn](http://www.linkedin.com/in/nicholasleeroth/)
