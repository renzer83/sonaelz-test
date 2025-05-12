locals {
  global_vars = fileexists(find_in_parent_folders("global/global.yaml")) ? yamldecode(file(find_in_parent_folders("global/global.yaml"))) : {}
  subscription_vars = try(
    yamldecode(file(
      fileexists("${get_terragrunt_dir()}/subscription.yaml")
      ? "${get_terragrunt_dir()}/subscription.yaml"
      : find_in_parent_folders("subscription.yaml")
    )),
    {}
  )
  tenant_id       = local.global_vars.tenant_id
  subscription_id = try(local.subscription_vars.subscription_id, "")
}


remote_state {
  backend = "azurerm"
  config = {
    subscription_id      = try(local.global_vars.tf_subscription_id, local.subscription_id)
    resource_group_name  = local.global_vars.resource_group_name
    storage_account_name = local.global_vars.storage_account_name
    container_name       = local.global_vars.container_name
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  features {}
  tenant_id       = "${local.tenant_id}"
  subscription_id = "${local.subscription_id}"
}
EOF
}

terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }
  extra_arguments "timeout_args" {
    commands  = ["apply", "plan", "destroy"]
    arguments = [
      "-lock-timeout=120m"
    ]
  }
  before_hook "convert_https_to_ssh" {
    commands = ["init"]
    execute  = ["bash", "-c", "find . -name 'main.tf' -type f -exec grep -l 'git::https://github.com/' {} \\; | xargs -I{} sed -i.bak 's|git::https://github.com/|git@github.com:|g' {} && find . -name '*.bak' -delete"]
  }   
}

inputs = merge(
  local.global_vars,
  try(local.subscription_vars, {})
)