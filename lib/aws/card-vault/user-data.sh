#!/bin/bash

yum update -y \
    && yum -y install docker \
    && service docker start \
    && docker pull juspaydotin/hyperswitch-card-vault:latest

aws s3 cp s3://{{BUCKET_NAME}}/{{ENV_FILE}} /home/ec2-user/.env

docker run --restart unless-stopped --env-file /home/ec2-user/.env -d --net=host juspaydotin/hyperswitch-card-vault:latest
