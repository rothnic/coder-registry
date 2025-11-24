run "defaults_are_correct" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder"
  }

  assert {
    condition     = var.opencode_provider == "copilot"
    error_message = "Default provider should be 'copilot'"
  }

  assert {
    condition     = var.report_tasks == true
    error_message = "Task reporting should be enabled by default"
  }

  assert {
    condition     = var.resume_session == true
    error_message = "Session resumption should be enabled by default"
  }

  assert {
    condition     = var.install_method == "npm"
    error_message = "Default install method should be 'npm'"
  }

  assert {
    condition     = resource.coder_env.mcp_app_status_slug.name == "CODER_MCP_APP_STATUS_SLUG"
    error_message = "Status slug env var should be created"
  }

  assert {
    condition     = resource.coder_env.mcp_app_status_slug.value == "opencode"
    error_message = "Status slug value should be 'opencode'"
  }
}

run "github_token_creates_env_var" {
  command = plan

  variables {
    agent_id     = "test-agent"
    workdir      = "/home/coder"
    github_token = "test_github_token_abc123"
  }

  assert {
    condition     = length(resource.coder_env.github_token) == 1
    error_message = "github_token env var should be created when token is provided"
  }

  assert {
    condition     = resource.coder_env.github_token[0].name == "GITHUB_TOKEN"
    error_message = "github_token env var name should be 'GITHUB_TOKEN'"
  }

  assert {
    condition     = resource.coder_env.github_token[0].value == "test_github_token_abc123"
    error_message = "github_token env var value should match input"
  }
}

run "github_token_not_created_when_empty" {
  command = plan

  variables {
    agent_id     = "test-agent"
    workdir      = "/home/coder"
    github_token = ""
  }

  assert {
    condition     = length(resource.coder_env.github_token) == 0
    error_message = "github_token env var should not be created when empty"
  }
}

run "opencode_provider_env_var_created" {
  command = plan

  variables {
    agent_id          = "test-agent"
    workdir           = "/home/coder"
    opencode_provider = "anthropic"
  }

  assert {
    condition     = length(resource.coder_env.opencode_provider) == 1
    error_message = "opencode_provider env var should be created when provider is specified"
  }

  assert {
    condition     = resource.coder_env.opencode_provider[0].name == "OPENCODE_PROVIDER"
    error_message = "opencode_provider env var name should be 'OPENCODE_PROVIDER'"
  }

  assert {
    condition     = resource.coder_env.opencode_provider[0].value == "anthropic"
    error_message = "opencode_provider env var value should match input"
  }
}

run "install_method_validation" {
  command = plan

  variables {
    agent_id       = "test-agent"
    workdir        = "/home/coder"
    install_method = "curl"
  }

  assert {
    condition     = contains(["npm", "curl"], var.install_method)
    error_message = "Install method should be either 'npm' or 'curl'"
  }
}

run "workdir_trimmed_of_trailing_slash" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder/project/"
  }

  assert {
    condition     = local.workdir == "/home/coder/project"
    error_message = "workdir should be trimmed of trailing slash"
  }
}

run "app_slug_is_consistent" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder"
  }

  assert {
    condition     = local.app_slug == "opencode"
    error_message = "app_slug should be 'opencode'"
  }

  assert {
    condition     = local.module_dir_name == ".opencode-module"
    error_message = "module_dir_name should be '.opencode-module'"
  }
}

run "custom_opencode_config" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder"
    opencode_config = jsonencode({
      theme = "dark"
    })
  }

  assert {
    condition     = var.opencode_config != ""
    error_message = "Custom opencode config should be set"
  }
}

run "task_reporting_prompt_included" {
  command = plan

  variables {
    agent_id     = "test-agent"
    workdir      = "/home/coder"
    report_tasks = true
  }

  assert {
    condition     = length(local.final_system_prompt) > 0
    error_message = "final_system_prompt should be computed"
  }

  assert {
    condition     = can(regex("Task Reporting", local.final_system_prompt))
    error_message = "Task reporting prompt should be included when report_tasks is true"
  }
}

run "task_reporting_prompt_excluded" {
  command = plan

  variables {
    agent_id     = "test-agent"
    workdir      = "/home/coder"
    report_tasks = false
  }

  assert {
    condition     = !can(regex("Task Reporting", local.final_system_prompt))
    error_message = "Task reporting prompt should not be included when report_tasks is false"
  }
}

run "version_defaults_to_latest" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder"
  }

  assert {
    condition     = var.opencode_version == "latest"
    error_message = "OpenCode version should default to 'latest'"
  }
}

run "agentapi_version_is_set" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder"
  }

  assert {
    condition     = var.agentapi_version == "v0.10.0"
    error_message = "AgentAPI version should be set to v0.10.0"
  }
}

run "mcp_servers_config" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder"
    mcp_servers = jsonencode({
      filesystem = {
        command = "npx"
        args    = ["-y", "@modelcontextprotocol/server-filesystem", "/workspaces"]
      }
    })
  }

  assert {
    condition     = var.mcp_servers != ""
    error_message = "MCP servers configuration should be provided"
  }
}

run "opencode_model_config" {
  command = plan

  variables {
    agent_id       = "test-agent"
    workdir        = "/home/coder"
    opencode_model = "claude-3.7-sonnet"
  }

  assert {
    condition     = var.opencode_model == "claude-3.7-sonnet"
    error_message = "OpenCode model should be set to 'claude-3.7-sonnet'"
  }
}

run "mcp_and_model_combined" {
  command = plan

  variables {
    agent_id       = "test-agent"
    workdir        = "/home/coder"
    opencode_model = "gpt-4o"
    mcp_servers = jsonencode({
      github = {
        command = "npx"
        args    = ["-y", "@modelcontextprotocol/server-github"]
      }
    })
  }

  assert {
    condition     = var.opencode_model == "gpt-4o"
    error_message = "OpenCode model should be set"
  }

  assert {
    condition     = var.mcp_servers != ""
    error_message = "MCP servers should be configured"
  }
}

run "model_defaults_to_empty" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder"
  }

  assert {
    condition     = var.opencode_model == ""
    error_message = "OpenCode model should default to empty (provider default)"
  }

  assert {
    condition     = var.mcp_servers == ""
    error_message = "MCP servers should default to empty"
  }
}
