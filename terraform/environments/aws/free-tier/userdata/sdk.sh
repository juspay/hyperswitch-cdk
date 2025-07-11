#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/hyperswitch-frontend-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "Starting Hyperswitch Frontend setup (SDK)..."

# Install only necessary dependencies
sudo yum update -y
sudo yum install -y jq unzip

# Install SSM Agent
sudo yum install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

# Configure CloudFront URLs
API_URL="https://${app_cloudfront_url}"
SDK_URL="https://${sdk_cloudfront_url}"
echo "API URL: $API_URL"
echo "SDK URL: $SDK_URL"

# Download and setup SDK
cd /
sudo curl -L https://raw.githubusercontent.com/Shailesh-714/cdk-tf/refs/heads/main/environments/aws/free-tier/userdata/sdk_assets.zip --output sdk_assets.zip
sudo unzip -o sdk_assets.zip

# Replace placeholders in SDK files
sudo find /sdk_assets -type f -name "*.js" -exec sed -i "s|{{app_cloudfront_url}}|$API_URL|g" {} \;
sudo find /sdk_assets -type f -name "*.js" -exec sed -i "s|{{sdk_cloudfront_url}}|$SDK_URL|g" {} \;

# Create SDK directory structure
sudo mkdir -p /sdk/web/${sdk_version}/${sdk_sub_version}
sudo mv /sdk_assets/* /sdk/web/${sdk_version}/${sdk_sub_version}
sudo rm -rf /sdk_assets sdk_assets.zip

# Start SDK server
cd /sdk
echo "Starting Hyperswitch SDK server..."
nohup python3 -m http.server 9050 --bind 0.0.0.0 >/dev/null 2>&1 &

echo "SDK server started on port 9050"
echo "SDK available at: $SDK_URL/web/${sdk_version}/${sdk_sub_version}/HyperLoader.js"
