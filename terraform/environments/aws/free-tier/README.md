# Hyperswitch Free Tier Terraform Deployment

This Terraform configuration deploys a complete Hyperswitch stack optimized for AWS Free Tier usage.

## Features

- **Single EC2 Instance** (t2.micro) running all services:
  - Hyperswitch Router (Backend API) on port 80
  - Control Center (Admin UI) on port 9000
  - SDK Server on port 9050
  - Demo Application on port 5252
- **RDS PostgreSQL** (db.t3.micro) with automatic schema initialization
- **ElastiCache Redis** (cache.t3.micro)
- **Application Load Balancer** with multiple listeners
- **CloudFront Distributions** for HTTPS access
- **Automatic Database Migration** during EC2 startup

## Database Initialization

The database schema is automatically initialized during the EC2 instance startup:

1. PostgreSQL client is installed on the EC2 instance
2. The startup script waits for the RDS instance to be ready (up to 5 minutes)
3. It checks if the database schema already exists
4. If not, it downloads and applies the Hyperswitch schema (v1.107.0)
5. The initialization is idempotent - it won't re-run if the schema exists

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 0.12
- AWS CLI configured (optional, for easier access)

## Usage

1. **Clone the repository**:

   ```bash
   git clone https://github.com/juspay/hyperswitch-cdk.git
   cd hyperswitch-cdk/terraform/free-tier
   ```

2. **Create a `terraform.tfvars` file**:

   ```hcl
   aws_region    = "us-east-1"
   stack_name    = "hyperswitch-free"
   vpc_cidr      = "10.0.0.0/16"
   db_password   = "your-secure-password"
   admin_api_key = "your-admin-api-key"
   ```

3. **Initialize Terraform**:

   ```bash
   terraform init
   ```

4. **Plan the deployment**:

   ```bash
   terraform plan
   ```

5. **Apply the configuration**:

   ```bash
   terraform apply
   ```

6. **Access the services**:
   After deployment completes, Terraform will output the URLs:
   - **Hyperswitch API**: `https://<cloudfront-domain>/health`
   - **Control Center**: `https://<cloudfront-domain>/`
   - **SDK Assets**: `https://<cloudfront-domain>/0.27.2/v0/HyperLoader.js`
   - **Demo App**: `http://<alb-dns>:5252`

## Important Notes

### Free Tier Considerations

- **EC2**: 750 hours/month of t2.micro (covers 1 instance 24/7)
- **RDS**: 750 hours/month of db.t3.micro with 20GB storage
- **ElastiCache**: 750 hours/month of cache.t3.micro
- **ALB**: 750 hours/month + 15 LCUs
- **CloudFront**: 1TB data transfer out, 2M requests

### Security

- The RDS instance is in private subnets and only accessible from the EC2 instance
- All services are exposed through CloudFront for HTTPS
- SSH access is restricted to the VPC CIDR block
- Database password and admin API key should be kept secure

### Monitoring

- CloudWatch logs are enabled for RDS
- SSM Session Manager is configured for secure EC2 access
- Database initialization logs are available in the EC2 instance at `/var/log/cloud-init-output.log`

## Troubleshooting

### Database Initialization Issues

If the database initialization fails:

1. Connect to the EC2 instance using SSM Session Manager:

   ```bash
   aws ssm start-session --target <instance-id>
   ```

2. Check the cloud-init logs:

   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```

3. Manually test database connectivity:

   ```bash
   export PGPASSWORD="<your-db-password>"
   psql -h <rds-endpoint> -U hyperswitchuser -d hyperswitch_db -c "SELECT 1;"
   ```

4. Re-run the schema migration if needed:
   ```bash
   curl -o /tmp/schema.sql https://raw.githubusercontent.com/juspay/hyperswitch-cdk/main/lib/aws/migrations/v1.107.0/schema.sql
   psql -h <rds-endpoint> -U hyperswitchuser -d hyperswitch_db -f /tmp/schema.sql
   ```

### Service Health Checks

- **Router Health**: `curl http://localhost/health`
- **Control Center**: `curl http://localhost:9000/`
- **SDK Server**: `curl http://localhost:9050/`
- **Demo App**: `curl http://localhost:5252/`

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will permanently delete all resources including the database. Make sure to backup any important data before destroying.

## Cost Estimation (After Free Tier)

Monthly costs after the 12-month free tier expires:

- EC2 (t2.micro): ~$8.50
- RDS (db.t3.micro): ~$15
- ElastiCache (cache.t3.micro): ~$13
- ALB: ~$16 + data transfer
- CloudFront: Usage-based, typically $1-5
- **Total**: ~$55-60/month

## Support

For issues or questions:

- Create an issue in the [Hyperswitch CDK repository](https://github.com/juspay/hyperswitch-cdk/issues)
- Check the [Hyperswitch documentation](https://opensource.hyperswitch.io/)
