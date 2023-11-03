#!/bin/bash

sudo yum update -y
sudo yum install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

docker pull juspaydotin/hyperswitch-router:beta

curl https://raw.githubusercontent.com/juspay/hyperswitch/v1.55.0/config/development.toml > production.toml
cat << EOF >> .env
ROUTER__REDIS__HOST={{redis_host}}
ROUTER__MASTER_DATABASE__HOST={{db_host}}
ROUTER__REPLICA_DATABASE__HOST={{db_host}}
ROUTER__SERVER__HOST=0.0.0.0
ROUTER__MASTER_DATABASE__USERNAME={{db_username}}
ROUTER__MASTER_DATABASE__PASSWORD={{password}}
ROUTER__MASTER_DATABASE__DBNAME={{db_name}}
ROUTER__SERVER__BASE_URL=$(curl ifconfig.me)
ROUTER__SECRETS__ADMIN_API_KEY={{admin_api_key}}
EOF

docker run --env-file .env -p 80:8080 -v `pwd`/:/local/config juspaydotin/hyperswitch-router:beta ./router -f /local/config/production.toml