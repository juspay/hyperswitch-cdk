# Outputs for Networking Module

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

# Public Subnet Outputs
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "management_zone_subnet_ids" {
  description = "List of management zone subnet IDs"
  value       = aws_subnet.management_zone[*].id
}

output "external_incoming_zone_subnet_ids" {
  description = "List of external incoming zone subnet IDs"
  value       = aws_subnet.external_incoming_zone[*].id
}

# Private Subnet Outputs
output "isolated_subnet_ids" {
  description = "List of isolated subnet IDs"
  value       = aws_subnet.isolated[*].id
}

output "database_isolated_subnet_ids" {
  description = "List of database isolated subnet IDs"
  value       = aws_subnet.database_isolated[*].id
}

output "eks_worker_nodes_subnet_ids" {
  description = "List of EKS worker nodes subnet IDs"
  value       = aws_subnet.eks_worker_nodes[*].id
}

output "utils_zone_subnet_ids" {
  description = "List of utils zone subnet IDs"
  value       = aws_subnet.utils_zone[*].id
}

output "service_layer_zone_subnet_ids" {
  description = "List of service layer zone subnet IDs"
  value       = aws_subnet.service_layer_zone[*].id
}

output "data_stack_zone_subnet_ids" {
  description = "List of data stack zone subnet IDs"
  value       = aws_subnet.data_stack_zone[*].id
}

output "outgoing_proxy_lb_zone_subnet_ids" {
  description = "List of outgoing proxy LB zone subnet IDs"
  value       = aws_subnet.outgoing_proxy_lb_zone[*].id
}

output "outgoing_proxy_zone_subnet_ids" {
  description = "List of outgoing proxy zone subnet IDs"
  value       = aws_subnet.outgoing_proxy_zone[*].id
}

output "incoming_npci_zone_subnet_ids" {
  description = "List of incoming NPCI zone subnet IDs"
  value       = aws_subnet.incoming_npci_zone[*].id
}

output "eks_control_plane_zone_subnet_ids" {
  description = "List of EKS control plane zone subnet IDs"
  value       = aws_subnet.eks_control_plane_zone[*].id
}

output "incoming_web_envoy_zone_subnet_ids" {
  description = "List of incoming web envoy zone subnet IDs"
  value       = aws_subnet.incoming_web_envoy_zone[*].id
}

# Isolated Subnet Outputs (no internet access)
output "database_zone_subnet_ids" {
  description = "List of database zone subnet IDs"
  value       = aws_subnet.database_zone[*].id
}

output "locker_database_zone_subnet_ids" {
  description = "List of locker database zone subnet IDs"
  value       = aws_subnet.locker_database_zone[*].id
}

output "locker_server_zone_subnet_ids" {
  description = "List of locker server zone subnet IDs"
  value       = aws_subnet.locker_server_zone[*].id
}

output "elasticache_zone_subnet_ids" {
  description = "List of elasticache zone subnet IDs"
  value       = aws_subnet.elasticache_zone[*].id
}

# Route Table Outputs
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_with_nat_route_table_ids" {
  description = "List of private route table IDs with NAT"
  value       = aws_route_table.private_with_nat[*].id
}

output "isolated_route_table_id" {
  description = "ID of the isolated route table"
  value       = aws_route_table.isolated.id
}

# Subnet CIDR Blocks (for reference)
output "subnet_cidr_blocks" {
  description = "Map of all subnet CIDR blocks"
  value = {
    public                  = aws_subnet.public[*].cidr_block
    isolated                = aws_subnet.isolated[*].cidr_block
    database_isolated       = aws_subnet.database_isolated[*].cidr_block
    eks_worker_nodes        = aws_subnet.eks_worker_nodes[*].cidr_block
    utils_zone              = aws_subnet.utils_zone[*].cidr_block
    management_zone         = aws_subnet.management_zone[*].cidr_block
    locker_database_zone    = aws_subnet.locker_database_zone[*].cidr_block
    service_layer_zone      = aws_subnet.service_layer_zone[*].cidr_block
    data_stack_zone         = aws_subnet.data_stack_zone[*].cidr_block
    external_incoming_zone  = aws_subnet.external_incoming_zone[*].cidr_block
    database_zone           = aws_subnet.database_zone[*].cidr_block
    outgoing_proxy_lb_zone  = aws_subnet.outgoing_proxy_lb_zone[*].cidr_block
    outgoing_proxy_zone     = aws_subnet.outgoing_proxy_zone[*].cidr_block
    locker_server_zone      = aws_subnet.locker_server_zone[*].cidr_block
    elasticache_zone        = aws_subnet.elasticache_zone[*].cidr_block
    incoming_npci_zone      = aws_subnet.incoming_npci_zone[*].cidr_block
    eks_control_plane_zone  = aws_subnet.eks_control_plane_zone[*].cidr_block
    incoming_web_envoy_zone = aws_subnet.incoming_web_envoy_zone[*].cidr_block
    istio_lb_transit_zone   = aws_subnet.istio_lb_transit_zone[*].cidr_block
  }
}

output "subnet_ids" {
  description = "Map of all subnet IDs"
  value = {
    public                  = aws_subnet.public[*].id
    isolated                = aws_subnet.isolated[*].id
    database_isolated       = aws_subnet.database_isolated[*].id
    eks_worker_nodes        = aws_subnet.eks_worker_nodes[*].id
    utils_zone              = aws_subnet.utils_zone[*].id
    management_zone         = aws_subnet.management_zone[*].id
    locker_database_zone    = aws_subnet.locker_database_zone[*].id
    service_layer_zone      = aws_subnet.service_layer_zone[*].id
    data_stack_zone         = aws_subnet.data_stack_zone[*].id
    external_incoming_zone  = aws_subnet.external_incoming_zone[*].id
    database_zone           = aws_subnet.database_zone[*].id
    outgoing_proxy_lb_zone  = aws_subnet.outgoing_proxy_lb_zone[*].id
    outgoing_proxy_zone     = aws_subnet.outgoing_proxy_zone[*].id
    locker_server_zone      = aws_subnet.locker_server_zone[*].id
    elasticache_zone        = aws_subnet.elasticache_zone[*].id
    incoming_npci_zone      = aws_subnet.incoming_npci_zone[*].id
    eks_control_plane_zone  = aws_subnet.eks_control_plane_zone[*].id
    incoming_web_envoy_zone = aws_subnet.incoming_web_envoy_zone[*].id
    istio_lb_transit_zone   = aws_subnet.istio_lb_transit_zone[*].id
  }
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC Endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "ssm_vpc_endpoint_id" {
  description = "ID of the SSM VPC Endpoint"
  value       = aws_vpc_endpoint.ssm.id
}

output "ssmmessages_vpc_endpoint_id" {
  description = "ID of the SSM Messages VPC Endpoint"
  value       = aws_vpc_endpoint.ssmmessages.id
}

output "ec2messages_vpc_endpoint_id" {
  description = "ID of the EC2 Messages VPC Endpoint"
  value       = aws_vpc_endpoint.ec2messages.id
}

output "secretsmanager_vpc_endpoint_id" {
  description = "ID of the Secrets Manager VPC Endpoint"
  value       = aws_vpc_endpoint.secretsmanager.id
}

output "kms_vpc_endpoint_id" {
  description = "ID of the KMS VPC Endpoint"
  value       = aws_vpc_endpoint.kms.id
}

output "rds_vpc_endpoint_id" {
  description = "ID of the RDS VPC Endpoint"
  value       = aws_vpc_endpoint.rds.id
}
