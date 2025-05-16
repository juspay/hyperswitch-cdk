data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    {
      "Name" = var.name
    },
    var.tags
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      "Name" = "${var.name}-igw"
    },
    var.tags
  )
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.max_azs) : 0
  domain = "vpc"
  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${var.name}-nat-gw-eip" : "${var.name}-nat-gw-eip-${element(slice(data.aws_availability_zones.available.names, 0, var.max_azs), count.index)}"
    },
    var.tags
  )
}

locals {
  vpc_cidr_prefix_length = tonumber(split("/", var.cidr_block)[1])

  # Definitions based on CDK's subnetConfiguration array
  # Each key is the CDK name. base_netnum_start_index is unique for each type.
  # These will always be created if the VPC module is invoked, as per CDK behavior.
  subnet_configs = {
    "public-subnet-1"           = { type = "PUBLIC", cidr_mask = 24, base_netnum_start_index = 0 }
    "isolated-subnet-1"         = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 1 } # Note: CDK calls it isolated but type is P_W_E
    "database-isolated-subnet-1"= { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 2 } # Note: CDK calls it isolated but type is P_W_E
    "eks-worker-nodes-one-zone" = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 22, base_netnum_start_index = 3 }
    "utils-zone"                = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 4 }
    "management-zone"           = { type = "PUBLIC", cidr_mask = 24, base_netnum_start_index = 5 }
    "locker-database-zone"      = { type = "PRIVATE_ISOLATED", cidr_mask = 24, base_netnum_start_index = 6 }
    "service-layer-zone"        = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 7 }
    "data-stack-zone"           = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 8 }
    "external-incoming-zone"    = { type = "PUBLIC", cidr_mask = 24, base_netnum_start_index = 9 }
    "database-zone"             = { type = "PRIVATE_ISOLATED", cidr_mask = 24, base_netnum_start_index = 10 }
    "outgoing-proxy-lb-zone"    = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 11 }
    "outgoing-proxy-zone"       = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 12 }
    "locker-server-zone"        = { type = "PRIVATE_ISOLATED", cidr_mask = 24, base_netnum_start_index = 13 }
    "elasticache-zone"          = { type = "PRIVATE_ISOLATED", cidr_mask = 24, base_netnum_start_index = 14 }
    "incoming-npci-zone"        = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 15 }
    "eks-control-plane-zone"    = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 16 }
    "incoming-web-envoy-zone"   = { type = "PRIVATE_WITH_EGRESS", cidr_mask = 24, base_netnum_start_index = 17 }
  }

  # Flattened list for resource creation: one entry per (subnet_type_name, az_index)
  subnet_creation_list = flatten([
    for cdk_name, config in local.subnet_configs : [
      for az_idx in range(var.max_azs) : {
        key                   = "${cdk_name}-${az_idx}" # Unique key for for_each
        cdk_name              = cdk_name
        type                  = config.type
        cidr_mask_length_diff = config.cidr_mask - local.vpc_cidr_prefix_length
        # netnum must be unique for every subnet created
        netnum                = (config.base_netnum_start_index * var.max_azs) + az_idx # Each type gets a block of netnums for its AZs
        az_index              = az_idx
      }
    ]
  ])

  # Determine subnet ID for NAT Gateway placement (e.g., first AZ's "public-subnet-1")
  # This assumes "public-subnet-1" is always created and is suitable.
  nat_gateway_placement_subnet_ids = [
    for az_idx in range(var.max_azs) :
    aws_subnet.all_subnets["public-subnet-1-${az_idx}"].id
  ]
}

resource "aws_subnet" "all_subnets" {
  for_each = { for item in local.subnet_creation_list : item.key => item }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, each.value.cidr_mask_length_diff, each.value.netnum)
  availability_zone       = slice(data.aws_availability_zones.available.names, 0, var.max_azs)[each.value.az_index]
  map_public_ip_on_launch = each.value.type == "PUBLIC"

  tags = merge(
    {
      "Name"                                = format("%s-%s-%s", var.stack_prefix, replace(each.value.cdk_name, "_", "-"), slice(data.aws_availability_zones.available.names, 0, var.max_azs)[each.value.az_index])
      "kubernetes.io/role/elb"              = each.value.type == "PUBLIC" ? "1" : null
      "kubernetes.io/role/internal-elb"     = each.value.type == "PRIVATE_WITH_EGRESS" ? "1" : null
      "kubernetes.io/cluster/${var.stack_prefix}-eks-cluster" = (each.value.type == "PUBLIC" || each.value.type == "PRIVATE_WITH_EGRESS") ? "shared" : null
      "SubnetType"                          = each.value.type # For easier filtering
      "CDKName"                             = each.value.cdk_name # Original CDK name for reference
    },
    var.tags
  )
}

resource "aws_nat_gateway" "this" {
  count           = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.max_azs) : 0
  allocation_id   = aws_eip.nat[count.index].id
  subnet_id       = local.nat_gateway_placement_subnet_ids[count.index]
  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${var.name}-nat-gw" : "${var.name}-nat-gw-${slice(data.aws_availability_zones.available.names, 0, var.max_azs)[count.index]}"
    },
    var.tags
  )
  depends_on = [aws_internet_gateway.this, aws_subnet.all_subnets] # Ensure subnets are created first
}

# --- Route Tables ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge({ "Name" = "${var.name}-public-rt" }, var.tags)
}

resource "aws_route_table_association" "public_assoc" {
  for_each = {
    for k, s in aws_subnet.all_subnets : k => s if s.tags.SubnetType == "PUBLIC"
  }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.max_azs) : 0
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }
  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${var.name}-private-rt" : "${var.name}-private-rt-${slice(data.aws_availability_zones.available.names, 0, var.max_azs)[count.index]}"
    },
    var.tags
  )
}

locals {
  # Create a map from AZ name to the private route table ID in that AZ (if not single_nat_gateway)
  az_to_private_rt_id_map = var.enable_nat_gateway && !var.single_nat_gateway ? {
    for idx in range(var.max_azs) :
    slice(data.aws_availability_zones.available.names, 0, var.max_azs)[idx] => aws_route_table.private_rt[idx].id
  } : {}
}

resource "aws_route_table_association" "private_assoc" {
  for_each = {
    # Iterate over all subnets that are of type PRIVATE_WITH_EGRESS
    for k, s in aws_subnet.all_subnets : k => s if s.tags.SubnetType == "PRIVATE_WITH_EGRESS" && var.enable_nat_gateway
  }
  subnet_id      = each.value.id
  route_table_id = var.single_nat_gateway ? aws_route_table.private_rt[0].id : local.az_to_private_rt_id_map[each.value.availability_zone]
}

# PRIVATE_ISOLATED subnets do not get a dedicated route table with NAT Gateway.
# They use the VPC's main route table for intra-VPC traffic and have no direct internet egress.
# No explicit associations needed here beyond what the main route table provides by default.
