#!/bin/bash
set -e # Exit on error

# Install necessary packages
sudo yum update -y
sudo yum install -y docker aws-cli jq

# Start Docker service
sudo service docker start
sudo usermod -a -G docker ec2-user
# newgrp docker # This command might not work as expected in user data scripts as it's for interactive shells.
              # Docker commands below will be run with sudo or by root implicitly in user data.

# Fetch the encrypted .env file from S3
# Ensure the EC2 instance has an IAM role with s3:GetObject permission for this bucket/object
# and kms:Decrypt permission for the KMS key used to encrypt the .env file.
aws s3 cp s3://${env_s3_bucket_name}/${env_file_key} /home/ec2-user/locker.env

# At this point, /home/ec2-user/locker.env contains the KMS encrypted values.
# The application running inside Docker will need to:
# 1. Read this .env file.
# 2. For values that are KMS encrypted (like ENCRYPTED_MASTER_KEY), use AWS SDK to decrypt them using the KMS key.
#    The EC2 instance's IAM role must have kms:Decrypt permission on the specific key.
# 3. Use the decrypted values.

# Example: (This part depends heavily on how the Locker application is designed to consume secrets)
# If the application itself handles decryption using an SDK:
# You would just pass the .env file to the Docker container.

# If decryption needs to happen *before* starting the app and a new .env is created for the app:
# (This is a more complex scenario and requires careful handling of decrypted secrets)
#
# DECRYPTED_MASTER_KEY=$(aws kms decrypt --ciphertext-blob fileb:///path/to/encrypted_master_key_from_env_file --query Plaintext --output text | base64 --decode)
# ... and so on for other encrypted variables ...
# Then construct a new .env file with decrypted values to pass to Docker.
# For simplicity, assuming the application or its entrypoint script handles reading locker.env and decrypting.

# Pull and run the Locker Docker image
# Replace with the actual Docker image and command for the Locker application
# For example:
# docker pull your-locker-image:latest
# docker run -d --env-file /home/ec2-user/locker.env -p 8080:8080 your-locker-image:latest

echo "User data script for Locker EC2 finished. Locker application setup needs to be completed based on its specific requirements for consuming the .env file."
echo "Ensure the Locker Docker image is available and the run command is correct."
echo "The .env file is at /home/ec2-user/locker.env"
# Placeholder for actual docker run command for the locker
# The CDK code doesn't explicitly show the docker run command for the locker EC2,
# it focuses on setting up the environment for it.
