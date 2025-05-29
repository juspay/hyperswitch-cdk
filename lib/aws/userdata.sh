#!/bin/bash

sudo yum update -y
sudo yum install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user
newgrp docker
sudo yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Installing Hyperswitch Router application [Backend application]

docker pull juspaydotin/hyperswitch-router:v1.107.0-standalone

curl https://raw.githubusercontent.com/juspay/hyperswitch/v1.107.0/config/development.toml > production.toml
cat << EOF >> .env
ROUTER__REDIS__HOST={{redis_host}}
ROUTER__MASTER_DATABASE__HOST={{db_host}}
ROUTER__MASTER_DATABASE__USERNAME={{db_username}}
ROUTER__MASTER_DATABASE__PASSWORD={{password}}
ROUTER__MASTER_DATABASE__DBNAME={{db_name}}
ROUTER__REPLICA_DATABASE__HOST={{db_host}}
ROUTER__REPLICA_DATABASE__USERNAME={{db_username}}
ROUTER__REPLICA_DATABASE__PASSWORD={{password}}
ROUTER__REPLICA_DATABASE__DBNAME={{db_name}}
ROUTER__ANALYTICS__SQLX__HOST={{db_host}}
ROUTER__ANALYTICS__SQLX__USERNAME={{db_username}}
ROUTER__ANALYTICS__SQLX__PASSWORD={{password}}
ROUTER__ANALYTICS__SQLX__DBNAME={{db_name}}
ROUTER__LOCKER__MOCK_LOCKER=true
ROUTER__SERVER__HOST=0.0.0.0
ROUTER__SERVER__BASE_URL=https://{{app_cloudfront_url}}
ROUTER__SECRETS__ADMIN_API_KEY={{admin_api_key}}
EOF

sudo sed -i '/^origins/d; s/^wildcard_origin = false/wildcard_origin = true/' production.toml

docker run -d --env-file .env -p 80:8080 -v `pwd`/:/local/config juspaydotin/hyperswitch-router:v1.107.0-standalone ./router -f /local/config/production.toml


# Installing Hyperswitch control center

docker pull juspaydotin/hyperswitch-control-center:v1.29.9

cat << EOF >> .env
apiBaseUrl=https://{{app_cloudfront_url}}
sdkBaseUrl=https://{{sdk_cloudfront_url}}/0.27.2/v0/HyperLoader.js
EOF

docker run -d --env-file .env -p 9000:9000 juspaydotin/hyperswitch-control-center:v1.29.9
