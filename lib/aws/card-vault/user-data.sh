#!/bin/bash

yum update -y \
    && amazon-linux-extras install docker -y \
    && systemctl start docker \
    && systemctl enable docker \
    && docker pull juspaydotin/hyperswitch-card-vault:latest

aws s3 cp s3://{{BUCKET_NAME}}/{{ENV_FILE}} .env

docker run --restart unless-stopped --env-file .env -d --net=host juspaydotin/hyperswitch-card-vault:latest
