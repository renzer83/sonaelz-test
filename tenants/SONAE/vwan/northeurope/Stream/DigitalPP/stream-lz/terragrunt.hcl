include {
  path = find_in_parent_folders("root.hcl")
}


locals {
  stream_vars       = yamldecode(file("stream-lz.yaml"))
  location_vars     = yamldecode(file(find_in_parent_folders("location.yaml")))
  subscription_vars = fileexists("${get_parent_terragrunt_dir()}/subscription.yaml") ? yamldecode(file("${get_parent_terragrunt_dir()}/subscription.yaml")) : {}

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
    virtual_hub_resource_ids = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualHubs/mock-hub"
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
    virtual_hub_id = dependency.vhub.outputs.virtual_hub_resource_ids["hub1"]
    firewall_id    = dependency.firewall_policy.outputs.firewall_policy_resource_id    
    routes = [
      for route in local.stream_vars.routes : {
        name              = route.name
        destinations_type = route.destinations_type
        destinations      = route.destinations
        next_hop_type     = route.next_hop_type
        next_hop          = lookup(route, "use_firewall", false) ? dependency.firewall_policy.outputs.firewall_policy_resource_id : lookup(route, "next_hop", "")
      }
    ]
    virtual_networks = {
      for key, vnet in local.stream_vars.virtual_networks : key => {
        name                        = vnet.name
        location                    = local.location_vars.location
        address_space               = vnet.address_space
        virtual_hub_id              = dependency.vhub.outputs.virtual_hub_resource_ids["hub1"]
      }
    }    
  }
)