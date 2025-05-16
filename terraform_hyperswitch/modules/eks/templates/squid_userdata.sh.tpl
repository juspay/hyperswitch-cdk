#!/bin/bash
set -e

# Install Squid (if not already on the AMI)
if ! command -v squid &> /dev/null
then
    echo "Squid not found, installing..."
    sudo yum update -y
    sudo yum install -y squid
fi

# Install AWS CLI (if not already on the AMI)
if ! command -v aws &> /dev/null
then
    echo "AWS CLI not found, installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
fi

# Create directory for Squid configurations
sudo mkdir -p /etc/squid/conf.d
sudo mkdir -p /var/log/squid # Ensure log directory exists and is writable by Squid user
sudo chown squid:squid /var/log/squid # Or appropriate user for Squid

# Download Squid configurations from S3
# Ensure IAM role for EC2 has s3:GetObject on this bucket/prefix
echo "Downloading Squid configurations from s3://${bucket_name}/squid/"
aws s3 sync s3://${bucket_name}/squid/ /etc/squid/ --delete 
# This syncs all files from the s3 bucket's /squid/ prefix to /etc/squid/
# Ensure your squid.conf is correctly placed and references other files like blacklist.txt

# Configure Squid (example: ensure correct permissions, include custom configs)
# The main squid.conf should be part of the synced files.
# If squid.conf needs to include files from conf.d:
if [ -d "/etc/squid/conf.d" ]; then
    # Ensure the main squid.conf has an include directive like:
    # include /etc/squid/conf.d/*.conf
    # This step might be part of the AMI or the downloaded squid.conf itself.
    echo "Ensuring squid.conf includes from conf.d"
fi

# Initialize Squid cache directory (if not done by package install)
if [ ! -d "/var/spool/squid" ]; then
    echo "Initializing Squid cache directory..."
    sudo squid -z -N # -N prevents daemonizing, -z creates swap dirs
fi
sudo chown -R squid:squid /var/spool/squid # Or appropriate user

# Start Squid service
echo "Starting Squid service..."
sudo systemctl enable squid
sudo systemctl restart squid # Use restart to ensure it picks up new config

# (Optional) Setup a simple health check endpoint if needed by ALB
# For example, using a small web server or a custom Squid ACL + http_port
# This is not in the original CDK script but good for ALB health checks.
# Example: Python HTTP server on a specific port if Squid doesn't offer a direct health check URL
# nohup python -m SimpleHTTPServer 8088 > /tmp/health_server.log 2>&1 &

echo "Squid user data script finished."
