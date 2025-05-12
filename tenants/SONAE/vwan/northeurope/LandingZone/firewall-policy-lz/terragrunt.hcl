include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  firewall_policy_vars = yamldecode(file("firewall-policy-lz.yaml"))
  location             = yamldecode(file(find_in_parent_folders("location.yaml")))
  common_vars          = yamldecode(file(find_in_parent_folders("common.yaml")))
  subscription_vars    = fileexists("${get_parent_terragrunt_dir()}/subscription.yaml") ? yamldecode(file("${get_parent_terragrunt_dir()}/subscription.yaml")) : {}

}

terraform {
  # source = "git@github.com:sonaemc-iac-modules/terraform-azure-firewall-policy-lz.git"
  source = "git::ssh://git@github.com/sonaemc-iac-modules/terraform-azure-firewall-policy-lz.git//"
  # source =  "git::https://github.com/sonaemc-iac-modules/terraform-azure-firewall-policy-lz.git//"
}

generate "ephemeral_vars" {
  path      = "ephemeral_override.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
tags = ${jsonencode(local.firewall_policy_vars.tags)}
network_rule_collections = ${jsonencode(local.firewall_policy_vars.network_rule_collections)}
application_rule_collections = ${jsonencode(local.firewall_policy_vars.application_rule_collections)}
EOF
}

inputs = merge(
  local.firewall_policy_vars, local.location, local.common_vars, local.subscription_vars
);