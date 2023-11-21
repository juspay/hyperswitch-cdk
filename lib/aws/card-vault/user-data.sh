#!/bin/bash

yum update -y \
    && amazon-linux-extras install docker -y \
    && systemctl start docker \
    && systemctl enable docker \
    && docker pull juspaydotin/hyperswitch-card-vault:latest

cat << EOF >> .env
LOCKER__SERVER__HOST=0.0.0.0
LOCKER__SERVER__PORT=8080
LOCKER__LOG__CONSOLE__ENABLED=true
LOCKER__LOG__CONSOLE__LEVEL=DEBUG
LOCKER__LOG__CONSOLE__LOG_FORMAT=default

LOCKER__DATABASE__USERNAME={{db_user}} # add the database user created above
LOCKER__DATABASE__PASSWORD={{kms_enc_db_pass}} # add the kms encrypted password here (kms encryption process mentioned below)
LOCKER__DATABASE__HOST={{db_host}} # add the host of the database (database url)
LOCKER__DATABASE__PORT=5432 # if used differently mention here
LOCKER__DATABASE__DBNAME=locker

LOCKER__LIMIT__REQUEST_COUNT=100
LOCKER__LIMIT__DURATION=60

LOCKER__SECRETS__TENANT=hyperswitch
LOCKER__SECRETS__MASTER_KEY={{kms_enc_master_key}} # kms encrypted master key
LOCKER__SECRETS__LOCKER_PRIVATE_KEY={{kms_enc_lpriv_key}} # kms encrypted locker private key
LOCKER__SECRETS__TENANT_PUBLIC_KEY={{kms_enc_tpub_key}} # kms encrypted locker private key

LOCKER__KMS__KEY_ID={{kms_id}} # kms id used to encrypt it below
LOCKER__KMS__REGION={{kms_region}} # kms region used
EOF

docker run --restart unless-stopped --env-file .env -d --net=host juspaydotin/hyperswitch-card-vault:latest
