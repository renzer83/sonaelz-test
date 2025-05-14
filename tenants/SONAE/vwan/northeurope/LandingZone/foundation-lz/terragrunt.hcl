include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  foundation_vars   = yamldecode(file("foundation-lz.yaml"))
  common_vars       = yamldecode(file(find_in_parent_folders("common.yaml")))
  location_vars     = yamldecode(file(find_in_parent_folders("location.yaml")))
  subscription_vars = fileexists("${get_parent_terragrunt_dir()}/subscription.yaml") ? yamldecode(file("${get_parent_terragrunt_dir()}/subscription.yaml")) : {}

  merged_vars = merge(
    local.common_vars,
    local.location_vars,
    local.subscription_vars,
    local.foundation_vars
  )

}

terraform {
  source = "git@github.com:sonaemc-iac-modules/terraform-azure-foundation-lz.git?ref=feat/update"
}

dependency "firewall_policy" {
  config_path = "../firewall-policy-lz"

  mock_outputs = {
    firewall_policy_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sonae-neu-lz-network/providers/Microsoft.Network/firewallPolicies/policy-sonae-neu-lz"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = merge(
  local.merged_vars,
  {
    bgp_ip_address_instance_0 = local.foundation_vars.bgp_ip_address_instance_0
    bgp_ip_address_instance_1 = local.foundation_vars.bgp_ip_address_instance_1
    vpn_gateway_asn = local.foundation_vars.vpn_gateway_asn    
    virtual_hubs = {
      for key, hub in local.foundation_vars.virtual_hubs : key => {
        name                        = hub.name
        location                    = try(local.location_vars.location, "northeurope")
        address_prefix              = hub.address_prefix
        firewall_policy_resource_id = dependency.firewall_policy.outputs.firewall_policy_resource_id

        sku                    = try(hub.sku, local.common_vars.sku, "Standard")
        hub_routing_preference = try(hub.hub_routing_preference, local.common_vars.hub_routing_preference, "ASPath")
        express_route_gateway  = try(hub.express_route_gateway, local.common_vars.express_route_gateway, true)
        vpn_gateway            = try(hub.vpn_gateway, local.common_vars.vpn_gateway, false)
        p2s_gateway            = try(hub.p2s_gateway, local.common_vars.p2s_gateway, false)
      }
    }    
  }
)


generate "ephemeral_vars" {
  path      = "ephemeral_override.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
bgp_ip_address_instance_0= ${jsonencode(local.foundation_vars.bgp_ip_address_instance_0)}
bgp_ip_address_instance_1= ${jsonencode(local.foundation_vars.bgp_ip_address_instance_1)}
vpn_site_connections= ${jsonencode(local.foundation_vars.vpn_site_connections)}
vpn_gateway_asn= ${jsonencode(local.foundation_vars.vpn_gateway_asn)}
defaultroutetable_destinations = ${jsonencode(local.foundation_vars.defaultroutetable_destinations)}
storage_containers = ${jsonencode(local.foundation_vars.storage_containers)}
zones = ${jsonencode(local.foundation_vars.zones)}
sku = ${jsonencode(local.foundation_vars.sku)}
virtual_hubs = ${jsonencode({
  for key, hub in local.foundation_vars.virtual_hubs : key => {
    name                        = hub.name
    location                    = try(local.location_vars.location, "northeurope")
    address_prefix              = hub.address_prefix
    firewall_policy_resource_id = dependency.firewall_policy.outputs.firewall_policy_resource_id
    sku                         = try(hub.sku, local.common_vars.sku, "Standard")
    hub_routing_preference      = try(hub.hub_routing_preference, local.common_vars.hub_routing_preference, "ASPath")
    express_route_gateway       = try(hub.express_route_gateway, local.common_vars.express_route_gateway, true)
    vpn_gateway                 = try(hub.vpn_gateway, local.common_vars.vpn_gateway, false)
    p2s_gateway                 = try(hub.p2s_gateway, local.common_vars.p2s_gateway, false)
  }
})}
tags = ${jsonencode(local.foundation_vars.tags)}
EOF
}