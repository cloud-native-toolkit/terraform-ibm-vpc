
locals {
  tmp_dir           = "${path.cwd}/.tmp"
  zone_count        = 3
  vpc_zone_names    = [ for index in range(max(local.zone_count, var.address_prefix_count)): "${var.region}-${(index % local.zone_count) + 1}" ]
  prefix_name       = var.name_prefix != "" && var.name_prefix != null ? var.name_prefix : var.resource_group_name
  vpc_name          = lower(replace(var.name != "" ? var.name : "${local.prefix_name}-vpc", "_", "-"))
  vpc_id            = data.ibm_is_vpc.vpc.id
  security_group_count = var.provision ? 2 : 0
  security_group_ids = var.provision ? [ data.ibm_is_vpc.vpc.default_security_group, data.ibm_is_security_group.base.id ] : []
  acl_id            = data.ibm_is_vpc.vpc.default_network_acl
  crn               = data.ibm_is_vpc.vpc.resource_crn
  ipv4_cidr_provided = var.address_prefix_count > 0 && length(var.address_prefixes) >= var.address_prefix_count
  ipv4_cidr_block    = local.ipv4_cidr_provided ? var.address_prefixes : [ for val in range(var.address_prefix_count): "" ]
  provision_cidr     = var.provision && local.ipv4_cidr_provided
  base_security_group_name = var.base_security_group_name != null && var.base_security_group_name != "" ? var.base_security_group_name : "${local.vpc_name}-base"
}

resource ibm_is_vpc vpc {
  count = var.provision ? 1 : 0

  name                        = local.vpc_name
  resource_group              = var.resource_group_id
  address_prefix_management   = local.ipv4_cidr_provided ? "manual" : "auto"
  default_security_group_name = "${local.vpc_name}-default"
  default_network_acl_name    = "${local.vpc_name}-default"
  default_routing_table_name  = "${local.vpc_name}-default"
}

data ibm_is_vpc vpc {
  depends_on = [ibm_is_vpc.vpc]

  name = local.vpc_name
}

resource ibm_is_vpc_address_prefix cidr_prefix {
  count = local.provision_cidr ? var.address_prefix_count : 0

  name  = "${local.vpc_name}-cidr-${format("%02s", count.index)}"
  zone  = local.vpc_zone_names[count.index]
  vpc   = data.ibm_is_vpc.vpc.id
  cidr  = local.ipv4_cidr_block[count.index]
  is_default = count.index < local.zone_count
}

resource ibm_is_network_acl_rule allow_internal_ingress {
  network_acl    = data.ibm_is_vpc.vpc.default_network_acl
  name           = "allow-internal-ingress"
  action         = "allow"
  source         = var.internal_cidr
  destination    = var.internal_cidr
  direction      = "inbound"
}

resource ibm_is_network_acl_rule allow_internal_egress {
  network_acl    = data.ibm_is_vpc.vpc.default_network_acl
  name           = "allow-internal-ingress"
  action         = "allow"
  source         = var.internal_cidr
  destination    = var.internal_cidr
  direction      = "outbound"
}

resource ibm_is_network_acl_rule deny_external_ssh {
  network_acl    = data.ibm_is_vpc.vpc.default_network_acl
  name           = "deny-external-ssh"
  action         = "deny"
  source         = "0.0.0.0/0"
  destination    = "0.0.0.0/0"
  direction      = "inbound"
  tcp {
    port_max        = 22
    port_min        = 22
    source_port_max = 22
    source_port_min = 22
  }
}

resource ibm_is_network_acl_rule deny_external_rdp {
  network_acl    = data.ibm_is_vpc.vpc.default_network_acl
  name           = "deny-external-rdp"
  action         = "deny"
  source         = "0.0.0.0/0"
  destination    = "0.0.0.0/0"
  direction      = "inbound"
  tcp {
    port_max        = 3389
    port_min        = 3389
    source_port_max = 3389
    source_port_min = 3389
  }
}

resource ibm_is_network_acl_rule deny_external_ingress {
  network_acl    = data.ibm_is_vpc.vpc.default_network_acl
  name           = "deny-external-ingress"
  action         = "deny"
  source         = "0.0.0.0/0"
  destination    = "0.0.0.0/0"
  direction      = "inbound"
}

resource ibm_is_security_group base {
  count = var.provision ? 1 : 0

  name = local.base_security_group_name
  vpc  = data.ibm_is_vpc.vpc.id
  resource_group = var.resource_group_id
}

data ibm_is_security_group base {
  depends_on = [ibm_is_security_group.base]

  name = local.base_security_group_name
}

resource null_resource print_sg_name {
  depends_on = [data.ibm_is_security_group.base]

  provisioner "local-exec" {
    command = "echo 'SG name: ${data.ibm_is_security_group.base.name != null ? data.ibm_is_security_group.base.name : "null"}'"
  }
}

# from https://cloud.ibm.com/docs/vpc?topic=vpc-service-endpoints-for-vpc
resource ibm_is_security_group_rule default_inbound_ping {
  group     = data.ibm_is_vpc.vpc.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"

  icmp {
    type = 8
  }
}

resource ibm_is_security_group_rule default_inbound_http {
  group     = data.ibm_is_vpc.vpc.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource ibm_is_security_group_rule cse_dns_1 {
  count = local.security_group_count

  group     = local.security_group_ids[count.index]
  direction = "outbound"
  remote    = "161.26.0.10"
  udp {
    port_min = 53
    port_max = 53
  }
}

resource ibm_is_security_group_rule cse_dns_2 {
  count = local.security_group_count

  group     = local.security_group_ids[count.index]
  direction = "outbound"
  remote    = "161.26.0.11"
  udp {
    port_min = 53
    port_max = 53
  }
}

resource ibm_is_security_group_rule private_dns_1 {
  count = local.security_group_count

  group     = local.security_group_ids[count.index]
  direction = "outbound"
  remote    = "161.26.0.7"
  udp {
    port_min = 53
    port_max = 53
  }
}

resource ibm_is_security_group_rule private_dns_2 {
  count = local.security_group_count

  group     = local.security_group_ids[count.index]
  direction = "outbound"
  remote    = "161.26.0.8"
  udp {
    port_min = 53
    port_max = 53
  }
}
