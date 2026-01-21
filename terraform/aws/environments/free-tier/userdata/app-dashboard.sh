#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/hyperswitch-backend-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "Starting Hyperswitch Backend setup (Router + Control Center)..."

# Add swap space for t2.micro
echo "Adding swap space..."
sudo dd if=/dev/zero of=/swapfile bs=128M count=16
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

# Install dependencies
sudo yum update -y
sudo yum install -y docker jq postgresql15 git wget

# Start Docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker

# Install SSM Agent
sudo yum install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

export LC_ALL=en_US.UTF-8
export PGPASSWORD="${db_password}"

# Wait for database
echo "Waiting for database..."
for i in {1..60}; do
    if pg_isready -h ${db_host} -p 5432 -U ${db_username}; then
        echo "Database ready!"
        break
    fi
    sleep 10
done

# Setup application directory
sudo mkdir -p /opt/hyperswitch
cd /opt/hyperswitch

# Download official configuration files
echo "Downloading official Hyperswitch configuration files..."
curl -o docker_compose.toml https://raw.githubusercontent.com/juspay/hyperswitch/refs/tags/${router_version}/config/docker_compose.toml
curl -o dashboard.toml https://raw.githubusercontent.com/juspay/hyperswitch/refs/tags/${router_version}/config/dashboard.toml

# Check and run migrations if needed
if ! psql -h ${db_host} -U ${db_username} -d ${db_name} -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='merchant_account'" 2>/dev/null | grep -q 1; then
    echo "Running database migrations..."

    # Create a temporary directory for migrations
    mkdir -p /tmp/hyperswitch-migrations
    cd /tmp/hyperswitch-migrations

    # Clone the entire repository at the specific version
    echo "Cloning Hyperswitch repository at version ${router_version}..."
    git clone --depth=1 --branch ${router_version} https://github.com/juspay/hyperswitch.git .

    # Run migrations using Docker container with cargo-binstall for faster setup
    echo "Executing database migrations..."
    docker run --rm \
        -v /tmp/hyperswitch-migrations:/app \
        -w /app \
        -e DATABASE_URL="postgresql://${db_username}:${db_password}@${db_host}:5432/${db_name}" \
        --network host \
        rust:latest \
        bash -c "
      curl -fsSL https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash &&
      cargo binstall diesel_cli just --no-confirm &&
      just migrate
    "

    # Cleanup
    cd /opt/hyperswitch
    rm -rf /tmp/hyperswitch-migrations
    echo "Database migrations completed successfully!"
else
    echo "Database already initialized, skipping migrations."
fi

sudo chown -R ec2-user:ec2-user /opt/hyperswitch

# Create environment file with proper overrides
cat >/opt/hyperswitch/.env <<EOF
# Database Configuration Overrides
ROUTER__MASTER_DATABASE__HOST=${db_host}
ROUTER__MASTER_DATABASE__USERNAME=${db_username}
ROUTER__MASTER_DATABASE__PASSWORD=${db_password}
ROUTER__MASTER_DATABASE__DBNAME=${db_name}
ROUTER__REPLICA_DATABASE__HOST=${db_host}
ROUTER__REPLICA_DATABASE__USERNAME=${db_username}
ROUTER__REPLICA_DATABASE__PASSWORD=${db_password}
ROUTER__REPLICA_DATABASE__DBNAME=${db_name}

# Redis Configuration Override
ROUTER__REDIS__HOST=${redis_host}

# Analytics Configuration Overrides
ROUTER__ANALYTICS__SQLX__HOST=${db_host}
ROUTER__ANALYTICS__SQLX__USERNAME=${db_username}
ROUTER__ANALYTICS__SQLX__PASSWORD=${db_password}
ROUTER__ANALYTICS__SQLX__DBNAME=${db_name}

# Server Configuration Overrides
ROUTER__SERVER__BASE_URL=https://${app_cloudfront_url}
ROUTER__SECRETS__ADMIN_API_KEY=${admin_api_key}

# User Configuration Override
ROUTER__USER__BASE_URL=https://${app_cloudfront_url}

# Control Center Configuration
apiBaseUrl=https://${app_cloudfront_url}
sdkBaseUrl=https://${sdk_cloudfront_url}/web/${sdk_version}/${sdk_sub_version}
EOF

# Start services
echo "Starting Hyperswitch backend services..."

# Router with memory limit
echo "Starting Hyperswitch Router..."
docker pull juspaydotin/hyperswitch-router:${router_version}-standalone
docker run -d --name hyperswitch-router \
    --memory="512m" \
    --memory-swap="1g" \
    --env-file /opt/hyperswitch/.env \
    -p 8080:8080 \
    -v /opt/hyperswitch/docker_compose.toml:/local/config/docker_compose.toml \
    --restart unless-stopped \
    juspaydotin/hyperswitch-router:${router_version}-standalone ./router -f /local/config/docker_compose.toml

# Wait for router
echo "Waiting for router to be healthy..."
for i in {1..60}; do
    if curl -f http://localhost:8080/health >/dev/null 2>&1; then
        echo "Router is healthy!"
        break
    fi
    echo "Attempt $i/60: Router not ready yet..."
    sleep 5
done

# Update dashboard configuration
sed -i "s|api_url=\"http://localhost:8080\"|api_url=\"https://${app_cloudfront_url}\"|g" /opt/hyperswitch/dashboard.toml
sed -i "s|sdk_url=\"http://localhost:9050/HyperLoader.js\"|sdk_url=\"https://${sdk_cloudfront_url}/web/${sdk_version}/${sdk_sub_version}/HyperLoader.js\"|g" /opt/hyperswitch/dashboard.toml

# Control Center with memory limit
echo "Starting Control Center..."
docker pull juspaydotin/hyperswitch-control-center:${control_center_version}
docker run -d --name hyperswitch-control-center \
    --memory="384m" \
    --memory-swap="768m" \
    -p 9000:9000 \
    -v /opt/hyperswitch/dashboard.toml:/tmp/dashboard-config.toml \
    -e "configPath=/tmp/dashboard-config.toml" \
    --restart unless-stopped \
    juspaydotin/hyperswitch-control-center:${control_center_version}

echo "Backend setup completed successfully!"
echo "Services running:"
echo "- Router API: http://localhost:8080"
echo "- Control Center: http://localhost:9000"
