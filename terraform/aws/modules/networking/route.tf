# ==========================================================
#                       Route Tables
# ==========================================================

# Route Tables for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-public-rt"
    }
  )
}

# Route Tables for Private Subnets with NAT
resource "aws_route_table" "private_with_nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-private-nat-rt-${count.index + 1}"
    }
  )
}

# Route Table for Isolated Subnets (no internet access)
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-isolated-rt"
    }
  )
}

# ==========================================================
#                         Routes
# ==========================================================

# Routes for Public Subnets
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Routes for Private Subnets with NAT
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  route_table_id         = aws_route_table.private_with_nat[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# ==========================================================
#                 Route Table Associations
# ==========================================================

# --->  Route Table Associations for Public Subnets  <---

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "management_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.management_zone[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "external_incoming_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.external_incoming_zone[count.index].id
  route_table_id = aws_route_table.public.id
}

# --->  Route Table Associations for Private Subnets with NAT  <---

resource "aws_route_table_association" "isolated" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "database_isolated" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.database_isolated[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "eks_worker_nodes" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.eks_worker_nodes[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "utils_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.utils_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "service_layer_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.service_layer_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "data_stack_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.data_stack_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "outgoing_proxy_lb_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.outgoing_proxy_lb_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "outgoing_proxy_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.outgoing_proxy_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "incoming_npci_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.incoming_npci_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "eks_control_plane_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.eks_control_plane_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "incoming_web_envoy_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.incoming_web_envoy_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

# --->  Route Table Associations for Isolated Subnets  <---

resource "aws_route_table_association" "database_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.database_zone[count.index].id
  route_table_id = aws_route_table.isolated.id
}

resource "aws_route_table_association" "locker_database_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.locker_database_zone[count.index].id
  route_table_id = aws_route_table.isolated.id
}

resource "aws_route_table_association" "locker_server_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.locker_server_zone[count.index].id
  route_table_id = aws_route_table.isolated.id
}

resource "aws_route_table_association" "elasticache_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.elasticache_zone[count.index].id
  route_table_id = aws_route_table.isolated.id
}


