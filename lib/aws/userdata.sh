#!/bin/bash

sudo yum update -y
sudo yum install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

# Installing Hyperswitch Router application [Backend application]

docker pull juspaydotin/hyperswitch-router:v1.105.0-standalone

curl https://raw.githubusercontent.com/juspay/hyperswitch/v1.105.0/config/development.toml > production.toml
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
ROUTER__LOCKER__MOCK_LOCKER=true
ROUTER__SERVER__HOST=0.0.0.0
ROUTER__SERVER__BASE_URL=$(curl ifconfig.me)
ROUTER__SECRETS__ADMIN_API_KEY={{admin_api_key}}
EOF

docker run -d --env-file .env -p 80:8080 -v `pwd`/:/local/config juspaydotin/hyperswitch-router:v1.105.0-standalone ./router -f /local/config/production.toml


# Installing Hyperswitch control center

docker pull juspaydotin/hyperswitch-control-center:v1.17.0

cat << EOF >> .env
apiBaseUrl=http://$(curl ifconfig.me):80
sdkBaseUrl=http://$(curl ifconfig.me):80
EOF

docker run -d --env-file .env -p 9000:9000 juspaydotin/hyperswitch-control-center:v1.17.0
