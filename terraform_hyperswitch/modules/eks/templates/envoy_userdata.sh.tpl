#!/bin/bash
set -e

# Install Docker (if not already on the AMI)
if ! command -v docker &> /dev/null
then
    echo "Docker not found, installing..."
    sudo yum update -y
    sudo yum install -y docker
fi
sudo service docker start
sudo usermod -a -G docker ec2-user # Or the user your Envoy container will run as

# Install AWS CLI (if not already on the AMI)
if ! command -v aws &> /dev/null
then
    echo "AWS CLI not found, installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
fi

# Create directory for Envoy configuration
sudo mkdir -p /etc/envoy
sudo chown ec2-user:ec2-user /etc/envoy # Or appropriate user

# Download Envoy configuration from S3
# Ensure IAM role for EC2 has s3:GetObject on this bucket/key
echo "Downloading Envoy configuration from s3://${bucket_name}/envoy/envoy.yaml"
aws s3 cp s3://${bucket_name}/envoy/envoy.yaml /etc/envoy/envoy.yaml

# Run Envoy
# The exact command depends on the Envoy Docker image and how it expects configuration.
# This is a common way to run Envoy with a custom config.
# Ensure the AMI being used (var.envoy_ami_id) either has Envoy pre-installed or this script installs it.
# If the AMI is a generic Linux and Envoy is run as a Docker container:
ENVOY_IMAGE="envoyproxy/envoy:v1.28-latest" # Parameterize this if needed
echo "Pulling Envoy image: $ENVOY_IMAGE"
sudo docker pull $ENVOY_IMAGE

echo "Starting Envoy container..."
sudo docker run -d --name envoy \
  -p 80:10000 \
  -p 8081:8081 \
  -v /etc/envoy/envoy.yaml:/etc/envoy/envoy.yaml \
  $ENVOY_IMAGE \
  envoy -c /etc/envoy/envoy.yaml --service-cluster hyperswitch-envoy --service-node hyperswitch-envoy-node

# The ports (e.g., 10000 for http, 8081 for admin) should match your envoy.yaml configuration.
# Port 80 on host maps to Envoy's listener port (e.g., 10000).
# Port 8081 on host maps to Envoy's admin port.

echo "Envoy user data script finished."
