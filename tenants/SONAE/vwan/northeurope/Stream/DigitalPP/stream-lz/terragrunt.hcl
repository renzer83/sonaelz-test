include {
  path = find_in_parent_folders("root.hcl")
}


locals {
  stream_vars       = yamldecode(file("stream-lz.yaml"))
  location_vars     = yamldecode(file(find_in_parent_folders("location.yaml")))
  subscription_vars = fileexists("${get_parent_terragrunt_dir()}/subscription.yaml") ? yamldecode(file("${get_parent_terragrunt_dir()}/subscription.yaml")) : {}

  region_code = lookup(local.location_vars, "region_code", "ne")
  generated_label_route_table = [
    for key, vnet in local.stream_vars.virtual_networks : 
      "${vnet.name}-${local.stream_vars.environment}-${local.location_vars.region_code}"
  ]

  merged_vars = merge(
    local.location_vars,
    local.subscription_vars,
    local.stream_vars
  )

}

terraform {
  source = "git@github.com:sonaemc-iac-modules/terraform-azure-stream-lz.git?ref=feat/update"
}

dependency "vhub" {
  config_path  = find_in_parent_folders("LandingZone/foundation-lz")

  mock_outputs = {
    virtual_hub_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualHubs/mock-hub"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "firewall_policy" {
  config_path  = find_in_parent_folders("LandingZone/firewall-policy-lz")

  mock_outputs = {
    firewall_policy_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sonae-neu-lz-network/providers/Microsoft.Network/firewallPolicies/policy-sonae-neu-lz"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = merge(
  local.merged_vars,
  {
    #virtual_hub_id = dependency.vhub.outputs.virtual_hub_id
    #firewall_id    = dependency.firewall_policy.outputs.firewall_policy_resource_id 
    label_route_table = local.generated_label_route_table   
    virtual_hub_id = dependency.vhub.outputs.virtual_hub_resource_ids
    firewall_id    = dependency.vhub.outputs.firewall_ids["hub1"]     
    routes = [
      for route in local.stream_vars.routes : {
        name              = route.name
        destinations_type = route.destinations_type
        destinations      = route.destinations
        next_hop_type     = route.next_hop_type
        #next_hop          = lookup(route, "use_firewall", false) ? dependency.firewall_policy.outputs.firewall_policy_resource_id : lookup(route, "next_hop", "")
        next_hop          = lookup(route, "use_firewall", false) ? dependency.vhub.outputs.firewall_ids["hub1"] : lookup(route, "next_hop", "")
      }
    ]
    virtual_networks = {
      for key, vnet in local.stream_vars.virtual_networks : key => {
        name                        = vnet.name
        location                    = local.location_vars.location
        address_space               = vnet.address_space
        #virtual_hub_id              = dependency.vhub.outputs.virtual_hub_id
        virtual_hub_id              = dependency.vhub.outputs.virtual_hub_resource_ids["hub1"]
      }
    }    
  }
)

generate "ephemeral_vars" {
  path      = "ephemeral_override.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
label_route_table = ${jsonencode(local.generated_label_route_table)}
tags = ${jsonencode(local.stream_vars.tags)}
virtual_networks = ${jsonencode({
  for key, vnet in local.stream_vars.virtual_networks : key => {
    name                    = vnet.name
    location                = local.location_vars.location
    address_space           = vnet.address_space
    #virtual_hub_id         = dependency.vhub.outputs.virtual_hub_id
    virtual_hub_id          = dependency.vhub.outputs.virtual_hub_resource_ids["hub1"]
  }
})}
routes = ${jsonencode([
  for route in local.stream_vars.routes : {
    name              = route.name
    destinations_type = route.destinations_type
    destinations      = route.destinations
    next_hop_type     = route.next_hop_type
    next_hop          = lookup(route, "use_firewall", false) ?  dependency.vhub.outputs.firewall_ids["hub1"]  : lookup(route, "next_hop", "")
  }
])}
EOF
}