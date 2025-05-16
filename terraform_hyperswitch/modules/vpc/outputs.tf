output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "A list of availability zones speficied by max_azs variable"
  value       = slice(data.aws_availability_zones.available.names, 0, var.max_azs)
}

# Outputs for all created subnets, categorized by their CDK name and type
output "all_subnet_ids_by_cdk_name" {
  description = "A map of all created subnet IDs, keyed by their original CDK name and AZ index (e.g., 'public-subnet-1-0')."
  value       = { for k, s in aws_subnet.all_subnets : k => s.id }
}

output "public_subnet_ids" {
  description = "List of IDs of all PUBLIC subnets."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.SubnetType == "PUBLIC"]
}

output "private_with_egress_subnet_ids" {
  description = "List of IDs of all PRIVATE_WITH_EGRESS subnets."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.SubnetType == "PRIVATE_WITH_EGRESS"]
}

output "private_isolated_subnet_ids" {
  description = "List of IDs of all PRIVATE_ISOLATED subnets."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.SubnetType == "PRIVATE_ISOLATED"]
}

# Specific subnet group outputs based on CDK names
output "public_subnet_1_ids" {
  description = "List of IDs for 'public-subnet-1' across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "public-subnet-1"]
}

output "isolated_subnet_1_ids" { # Note: CDK type is PRIVATE_WITH_EGRESS
  description = "List of IDs for 'isolated-subnet-1' across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "isolated-subnet-1"]
}

output "database_isolated_subnet_1_ids" { # Note: CDK type is PRIVATE_WITH_EGRESS
  description = "List of IDs for 'database-isolated-subnet-1' across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "database-isolated-subnet-1"]
}

output "eks_worker_nodes_one_zone_subnet_ids" {
  description = "List of IDs for 'eks-worker-nodes-one-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "eks-worker-nodes-one-zone"]
}

output "utils_zone_subnet_ids" {
  description = "List of IDs for 'utils-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "utils-zone"]
}

output "management_zone_subnet_ids" {
  description = "List of IDs for 'management-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "management-zone"]
}

output "locker_database_zone_subnet_ids" {
  description = "List of IDs for 'locker-database-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "locker-database-zone"]
}

output "service_layer_zone_subnet_ids" {
  description = "List of IDs for 'service-layer-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "service-layer-zone"]
}

output "data_stack_zone_subnet_ids" {
  description = "List of IDs for 'data-stack-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "data-stack-zone"]
}

output "external_incoming_zone_subnet_ids" {
  description = "List of IDs for 'external-incoming-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "external-incoming-zone"]
}

output "database_zone_subnet_ids" {
  description = "List of IDs for 'database-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "database-zone"]
}

output "outgoing_proxy_lb_zone_subnet_ids" {
  description = "List of IDs for 'outgoing-proxy-lb-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "outgoing-proxy-lb-zone"]
}

output "outgoing_proxy_zone_subnet_ids" {
  description = "List of IDs for 'outgoing-proxy-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "outgoing-proxy-zone"]
}

output "locker_server_zone_subnet_ids" {
  description = "List of IDs for 'locker-server-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "locker-server-zone"]
}

output "elasticache_zone_subnet_ids" {
  description = "List of IDs for 'elasticache-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "elasticache-zone"]
}

output "incoming_npci_zone_subnet_ids" {
  description = "List of IDs for 'incoming-npci-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "incoming-npci-zone"]
}

output "eks_control_plane_zone_subnet_ids" {
  description = "List of IDs for 'eks-control-plane-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "eks-control-plane-zone"]
}

output "incoming_web_envoy_zone_subnet_ids" {
  description = "List of IDs for 'incoming-web-envoy-zone' subnets across AZs."
  value       = [for s in aws_subnet.all_subnets : s.id if s.tags.CDKName == "incoming-web-envoy-zone"]
}

# Default route table ID
output "default_route_table_id" {
  description = "The ID of the main route table associated with this VPC."
  value       = aws_vpc.this.main_route_table_id
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public_rt.id
}

output "private_route_table_ids_by_az" {
  description = "Map of private route table IDs, keyed by AZ name (if not single_nat_gateway)."
  value       = var.enable_nat_gateway && !var.single_nat_gateway ? { for k, rt in aws_route_table.private_rt : slice(data.aws_availability_zones.available.names, 0, var.max_azs)[k] => rt.id } : null
}

output "single_private_route_table_id" {
  description = "The ID of the single private route table (if single_nat_gateway is true)."
  value       = var.enable_nat_gateway && var.single_nat_gateway && length(aws_route_table.private_rt) > 0 ? aws_route_table.private_rt[0].id : null
}
