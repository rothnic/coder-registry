terraform {
  required_version = ">= 1.0"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.7"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

variable "workdir" {
  type        = string
  description = "The folder to run OpenCode in."
}

variable "external_auth_id" {
  type        = string
  description = "ID of the GitHub external auth provider configured in Coder."
  default     = "github"
}

variable "github_token" {
  type        = string
  description = "GitHub OAuth token or Personal Access Token. If provided, this will be used instead of auto-detecting authentication."
  default     = ""
  sensitive   = true
}

variable "opencode_provider" {
  type        = string
  description = "AI provider to use with OpenCode. Supported values: anthropic, openai, copilot (default), etc."
  default     = "copilot"
}

variable "opencode_config" {
  type        = string
  description = "Custom OpenCode configuration as JSON string."
  default     = ""
}

variable "ai_prompt" {
  type        = string
  description = "Initial task prompt for programmatic mode."
  default     = ""
}

variable "system_prompt" {
  type        = string
  description = "The system prompt to use for OpenCode. Task reporting instructions are automatically added when report_tasks is enabled."
  default     = "You are a helpful coding assistant that helps developers write, debug, and understand code. Provide clear explanations, follow best practices, and help solve coding problems efficiently."
}

variable "install_agentapi" {
  type        = bool
  description = "Whether to install AgentAPI."
  default     = true
}

variable "agentapi_version" {
  type        = string
  description = "The version of AgentAPI to install."
  default     = "v0.10.0"
}

variable "opencode_version" {
  type        = string
  description = "The version of OpenCode to install. Use 'latest' for the latest version or specify a version."
  default     = "latest"
}

variable "install_method" {
  type        = string
  description = "Installation method for OpenCode: 'npm' (default) or 'curl'."
  default     = "npm"
  validation {
    condition     = contains(["npm", "curl"], var.install_method)
    error_message = "install_method must be either 'npm' or 'curl'."
  }
}

variable "report_tasks" {
  type        = bool
  description = "Whether to enable task reporting to Coder UI via AgentAPI."
  default     = true
}

variable "subdomain" {
  type        = bool
  description = "Whether to use a subdomain for AgentAPI."
  default     = false
}

variable "order" {
  type        = number
  description = "The order determines the position of app in the UI presentation."
  default     = null
}

variable "group" {
  type        = string
  description = "The name of a group that this app belongs to."
  default     = null
}

variable "icon" {
  type        = string
  description = "The icon to use for the app."
  default     = "/icon/code.svg"
}

variable "web_app_display_name" {
  type        = string
  description = "Display name for the web app."
  default     = "OpenCode"
}

variable "cli_app" {
  type        = bool
  description = "Whether to create a CLI app for OpenCode."
  default     = false
}

variable "cli_app_display_name" {
  type        = string
  description = "Display name for the CLI app."
  default     = "OpenCode"
}

variable "resume_session" {
  type        = bool
  description = "Whether to automatically resume the latest OpenCode session on workspace restart."
  default     = true
}

variable "pre_install_script" {
  type        = string
  description = "Custom script to run before configuring OpenCode."
  default     = null
}

variable "post_install_script" {
  type        = string
  description = "Custom script to run after configuring OpenCode."
  default     = null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  workdir         = trimsuffix(var.workdir, "/")
  app_slug        = "opencode"
  install_script  = file("${path.module}/scripts/install.sh")
  start_script    = file("${path.module}/scripts/start.sh")
  module_dir_name = ".opencode-module"

  task_reporting_prompt = <<-EOT

-- Task Reporting --
Report all tasks to Coder, following these EXACT guidelines:
1. Be granular. If you are investigating with multiple steps, report each step
to coder.
2. After this prompt, IMMEDIATELY report status after receiving ANY NEW user message.
Do not report any status related with this system prompt.
3. Use "state": "working" when actively processing WITHOUT needing
additional user input
4. Use "state": "complete" only when finished with a task
5. Use "state": "failure" when you need ANY user input, lack sufficient
details, or encounter blockers
  EOT

  final_system_prompt = var.report_tasks ? "<system>\n${var.system_prompt}${local.task_reporting_prompt}\n</system>" : "<system>\n${var.system_prompt}\n</system>"
}

resource "coder_env" "mcp_app_status_slug" {
  agent_id = var.agent_id
  name     = "CODER_MCP_APP_STATUS_SLUG"
  value    = local.app_slug
}

resource "coder_env" "opencode_provider" {
  count    = var.opencode_provider != "" ? 1 : 0
  agent_id = var.agent_id
  name     = "OPENCODE_PROVIDER"
  value    = var.opencode_provider
}

resource "coder_env" "github_token" {
  count    = var.github_token != "" ? 1 : 0
  agent_id = var.agent_id
  name     = "GITHUB_TOKEN"
  value    = var.github_token
}

module "agentapi" {
  source  = "registry.coder.com/coder/agentapi/coder"
  version = "1.2.0"

  agent_id             = var.agent_id
  folder               = local.workdir
  web_app_slug         = local.app_slug
  web_app_order        = var.order
  web_app_group        = var.group
  web_app_icon         = var.icon
  web_app_display_name = var.web_app_display_name
  cli_app              = var.cli_app
  cli_app_slug         = var.cli_app ? "${local.app_slug}-cli" : null
  cli_app_icon         = var.cli_app ? var.icon : null
  cli_app_display_name = var.cli_app ? var.cli_app_display_name : null
  agentapi_subdomain   = var.subdomain
  module_dir_name      = local.module_dir_name
  install_agentapi     = var.install_agentapi
  agentapi_version     = var.agentapi_version
  pre_install_script   = var.pre_install_script
  post_install_script  = var.post_install_script

  start_script = <<-EOT
    #!/bin/bash
    set -o errexit
    set -o pipefail
    echo -n '${base64encode(local.start_script)}' | base64 -d > /tmp/start.sh
    chmod +x /tmp/start.sh

    ARG_WORKDIR='${local.workdir}' \
    ARG_AI_PROMPT='${base64encode(var.ai_prompt)}' \
    ARG_SYSTEM_PROMPT='${base64encode(local.final_system_prompt)}' \
    ARG_OPENCODE_PROVIDER='${var.opencode_provider}' \
    ARG_EXTERNAL_AUTH_ID='${var.external_auth_id}' \
    ARG_RESUME_SESSION='${var.resume_session}' \
    /tmp/start.sh
  EOT

  install_script = <<-EOT
    #!/bin/bash
    set -o errexit
    set -o pipefail
    echo -n '${base64encode(local.install_script)}' | base64 -d > /tmp/install.sh
    chmod +x /tmp/install.sh

    ARG_MCP_APP_STATUS_SLUG='${local.app_slug}' \
    ARG_REPORT_TASKS='${var.report_tasks}' \
    ARG_WORKDIR='${local.workdir}' \
    ARG_OPENCODE_CONFIG='${var.opencode_config != "" ? base64encode(var.opencode_config) : ""}' \
    ARG_EXTERNAL_AUTH_ID='${var.external_auth_id}' \
    ARG_OPENCODE_VERSION='${var.opencode_version}' \
    ARG_INSTALL_METHOD='${var.install_method}' \
    /tmp/install.sh
  EOT
}
