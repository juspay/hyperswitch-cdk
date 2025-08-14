# Hyperswitch Free Tier Terraform Deployment

This Terraform configuration deploys a complete Hyperswitch stack optimized for AWS Free Tier usage.

## Architecture Overview

- **Two EC2 Instances** (t2.micro each):
  - **Backend Instance**: Runs Hyperswitch Router (port 8080) and Control Center (port 9000)
  - **Frontend Instance**: Runs SDK Server (port 9050) and Demo Application (port 5252)
- **RDS PostgreSQL** (db.t3.micro) with automatic schema initialization
- **ElastiCache Redis** (cache.t3.micro) for caching
- **Application Load Balancer** with multiple target groups
- **CloudFront Distributions** (4 separate distributions for HTTPS access)
- **NAT Gateway** for private subnet connectivity
- **VPC** with public and private subnets across multiple AZs

## Features

- **High Availability**: Services distributed across two EC2 instances
- **Secure Architecture**: RDS and ElastiCache in private subnets
- **HTTPS Enabled**: All services accessible via CloudFront with SSL/TLS
- **Automatic Database Migration**: Schema initialization during EC2 startup
- **Session Manager**: Secure EC2 access without SSH keys
- **CloudWatch Monitoring**: Logs and metrics for all services

## Database Initialization

The database schema is automatically initialized during the backend EC2 instance startup:

1. PostgreSQL client is installed on the backend EC2 instance
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
   git clone <your-repository-url>
   cd cdk-tf/environments/aws/free-tier
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

   **HTTPS URLs (via CloudFront):**

   - **Hyperswitch API**: `https://<app-cloudfront-domain>/`
   - **API Health Check**: `https://<app-cloudfront-domain>/health`
   - **Control Center**: `https://<control-center-cloudfront-domain>/`
   - **SDK Assets**: `https://<sdk-cloudfront-domain>/HyperLoader.js`
   - **Demo App**: `https://<demo-cloudfront-domain>/`

   **Direct HTTP URLs (via ALB - for testing):**

   - **Hyperswitch API**: `http://<alb-dns>:80`
   - **Control Center**: `http://<alb-dns>:9000`
   - **SDK Server**: `http://<alb-dns>:9050`
   - **Demo App**: `http://<alb-dns>:5252`

## Service Ports

| Service            | EC2 Instance | Internal Port | ALB Port | Access Method          |
| ------------------ | ------------ | ------------- | -------- | ---------------------- |
| Hyperswitch Router | Backend      | 8080          | 80       | CloudFront → ALB → EC2 |
| Control Center     | Backend      | 9000          | 9000     | CloudFront → ALB → EC2 |
| SDK Server         | Frontend     | 9050          | 9050     | CloudFront → ALB → EC2 |
| Demo App           | Frontend     | 5252          | 5252     | CloudFront → ALB → EC2 |

## Important Notes

### Free Tier Considerations

- **EC2**: 750 hours/month of t2.micro (covers 2 instances for ~375 hours each)
- **RDS**: 750 hours/month of db.t3.micro with 20GB storage
- **ElastiCache**: 750 hours/month of cache.t3.micro
- **ALB**: 750 hours/month + 15 LCUs
- **CloudFront**: 1TB data transfer out, 2M requests
- **NAT Gateway**: NOT included in free tier (charges apply)

### Security

- RDS and ElastiCache instances are in private subnets
- All services are exposed through CloudFront for HTTPS
- Security groups restrict access between components
- IAM roles follow least privilege principle
- Session Manager enabled for secure EC2 access

### Monitoring

- CloudWatch logs enabled for RDS
- SSM Session Manager configured for secure EC2 access
- Database initialization logs available at `/var/log/cloud-init-output.log`
- CloudWatch agent installed on EC2 instances

## Terraform Outputs

After successful deployment, you'll get these outputs:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output api_url
terraform output control_center_url
terraform output demo_app_url
terraform output backend_instance_id
terraform output frontend_instance_id
```

## Troubleshooting

### Database Initialization Issues

If the database initialization fails:

1. **Connect to the backend EC2 instance** using Session Manager:

   ```bash
   aws ssm start-session --target $(terraform output -raw backend_instance_id)
   ```

2. **Check the cloud-init logs**:

   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```

3. **Manually test database connectivity**:

   ```bash
   export PGPASSWORD="<your-db-password>"
   psql -h $(terraform output -raw rds_address) -U hyperswitchuser -d hyperswitch_db -c "SELECT 1;"
   ```

4. **Re-run the schema migration if needed**:
   ```bash
   curl -o /tmp/schema.sql https://raw.githubusercontent.com/juspay/hyperswitch/v1.107.0/migrations/2024-01-11-065756_users_create/up.sql
   psql -h $(terraform output -raw rds_address) -U hyperswitchuser -d hyperswitch_db -f /tmp/schema.sql
   ```

### Service Health Checks

**On Backend Instance:**

```bash
# Connect to backend instance
aws ssm start-session --target $(terraform output -raw backend_instance_id)

# Check services
curl http://localhost:8080/health  # Router
curl http://localhost:9000/         # Control Center
```

**On Frontend Instance:**

```bash
# Connect to frontend instance
aws ssm start-session --target $(terraform output -raw frontend_instance_id)

# Check services
curl http://localhost:9050/web/0.27.2/v0/HyperLoader.js  # SDK
curl http://localhost:5252/                              # Demo App
```

### Common Issues

1. **Services not responding**: Check if EC2 instances are healthy in the target groups
2. **Database connection errors**: Verify security group rules and RDS status
3. **CloudFront 502 errors**: Wait a few minutes for services to fully start
4. **High latency**: Ensure you're using the CloudFront URLs, not direct ALB URLs

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**⚠️ Warning**: This will permanently delete all resources including the database. Make sure to backup any important data before destroying.

## Cost Estimation

### During Free Tier (First 12 months)

- **EC2**: Free (2 × t2.micro = 750 hours total)
- **RDS**: Free (db.t3.micro)
- **ElastiCache**: Free (cache.t3.micro)
- **ALB**: Free (750 hours)
- **CloudFront**: Free (up to limits)
- **NAT Gateway**: ~$45/month (NOT free tier eligible)
- **Data Transfer**: Varies (1GB free)
- **Total**: ~$45-50/month

### After Free Tier

- **EC2** (2 × t2.micro): ~$17/month
- **RDS** (db.t3.micro): ~$15/month
- **ElastiCache** (cache.t3.micro): ~$13/month
- **ALB**: ~$16/month + data transfer
- **NAT Gateway**: ~$45/month + data transfer
- **CloudFront**: Usage-based, typically $1-5/month
- **Total**: ~$110-120/month

### Cost Optimization Tips

1. **Remove NAT Gateway**: Modify architecture to avoid private subnet requirements
2. **Use single EC2**: Combine all services on one instance (less reliable)
3. **Schedule instances**: Stop instances during off-hours
4. **Use Spot instances**: For non-production workloads

## Architecture Diagram

```
               Internet
                  ↓
          CloudFront (HTTPS)
                  ↓
       Application Load Balancer
                  ↓
┌─────────────────┬─────────────────┐
│ Backend EC2     │ Frontend EC2    │
│ - Router (8080) │ - SDK (9050)    │
│ - Control (9000)│ - Demo (5252)   │
└────────┬────────┴────────┬────────┘
         │                 │
         ↓                 ↓
    ┌────────┐        ┌────────┐
    │  RDS   │        │ Redis  │
    └────────┘        └────────┘
    (Private)         (Private)
```

## License

This Terraform configuration is provided as-is under the same license as the main project.
