# Example Terraform variables file
# Copy this to terraform.tfvars and fill in your values

# Required Variables
aws_region = "eu-west-1"    # AWS region for deployment
stack_name = "tf-free-tier" # Name prefix for all resources
vpc_cidr   = "10.0.0.0/16"  # CIDR block for VPC

# Database Configuration
db_password = "Hyperswitch123" # Required: Set a strong password

# Hyperswitch Configuration
admin_api_key = "test_admin" # Required: Your admin API key

# Optional: Customize these values if needed
az_count = 2 # Number of availability zones (default: 2)
# db_username = "hyperswitchuser"             # Database username (default: hyperswitchuser)
# db_name     = "hyperswitch_db"              # Database name (default: hyperswitch_db)

sdk_version     = "0.122.10"
sdk_sub_version = "v1" # Hyperswitch SDK version and sub-version to deploy
