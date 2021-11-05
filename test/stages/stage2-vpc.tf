module "dev_vpc" {
  source = "./module"

  resource_group_id    = module.resource_group.id
  resource_group_name  = module.resource_group.name
  region               = var.region
  name_prefix          = var.name_prefix
  address_prefix_count = var.address_prefix_count
  address_prefixes     = jsondecode(var.address_prefixes)
}
