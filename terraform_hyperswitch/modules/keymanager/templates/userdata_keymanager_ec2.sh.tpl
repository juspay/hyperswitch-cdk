#!/bin/bash
set -e # Exit on error

# Install necessary packages
sudo yum update -y
sudo yum install -y docker aws-cli jq

# Start Docker service
sudo service docker start
sudo usermod -a -G docker ec2-user

# Fetch the encrypted .env file from S3
# Ensure the EC2 instance has an IAM role with s3:GetObject permission for this bucket/object
# and kms:Decrypt permission for the KMS key used to encrypt the .env file.
aws s3 cp s3://${env_s3_bucket_name}/${env_file_key} /home/ec2-user/keymanager.env

# At this point, /home/ec2-user/keymanager.env contains the KMS encrypted values and plain TLS certs.
# The Keymanager application running inside Docker will need to:
# 1. Read this .env file.
# 2. For values that are KMS encrypted (like ENCRYPTED_MASTER_KEY), use AWS SDK to decrypt them using the KMS key.
#    The EC2 instance's IAM role must have kms:Decrypt permission on the specific key.
# 3. Use the decrypted values and plain certs.

# Pull and run the Keymanager Docker image
# This is a placeholder. Replace with the actual Docker image and command for your Keymanager application.
# Example:
# KEYMANAGER_IMAGE="your-keymanager-image:latest"
# sudo docker pull $KEYMANAGER_IMAGE
# sudo docker run -d --name keymanager-app --env-file /home/ec2-user/keymanager.env -p 8080:8080 $KEYMANAGER_IMAGE

echo "User data script for Keymanager EC2 finished."
echo "The .env file is at /home/ec2-user/keymanager.env"
echo "Ensure the Keymanager Docker image is available and the run command is correct."
echo "The Keymanager application needs to handle the .env file (including KMS decryption for relevant fields)."
