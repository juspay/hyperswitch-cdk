import os
import json
import boto3
import urllib3

secrets_manager = boto3.client('secretsmanager')
s3_client = boto3.client('s3')
kms_client = boto3.client('kms')

http = urllib3.PoolManager()


def worker():
    secret_arn = os.environ['SECRET_MANAGER_ARN']
    secret_value_response = secrets_manager.get_secret_value(SecretId=secret_arn)
    credentials = json.loads(secret_value_response['SecretString'])

    kms_fun = kms_encryptor(credentials["kms_id"], credentials["region"])
    enc_pl = lambda x: kms_fun(credentials[x])
    pl = lambda x: credentials[x]

    return """
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

LOCKER__DATABASE__USERNAME={pl("db_username")} # add the database user created above
LOCKER__DATABASE__PASSWORD={enc_pl("db_password")} # add the kms encrypted password here (kms encryption process mentioned below)
LOCKER__DATABASE__HOST={pl("db_host")} # add the host of the database (database url)
LOCKER__DATABASE__PORT=5432 # if used differently mention here
LOCKER__DATABASE__DBNAME=locker

LOCKER__LIMIT__REQUEST_COUNT=100
LOCKER__LIMIT__DURATION=60

LOCKER__SECRETS__TENANT=hyperswitch
LOCKER__SECRETS__MASTER_KEY={enc_pl("master_key")} # kms encrypted master key
LOCKER__SECRETS__LOCKER_PRIVATE_KEY={enc_pl("private_key")} # kms encrypted locker private key
LOCKER__SECRETS__TENANT_PUBLIC_KEY={enc_pl("public_key")} # kms encrypted locker private key

LOCKER__KMS__KEY_ID={pl("kms_id")} # kms id used to encrypt it below
LOCKER__KMS__REGION={pl("region")} # kms region used
EOF

docker run --restart unless-stopped --env-file .env -d --net=host juspaydotin/hyperswitch-card-vault:latest
"""


def kms_encryptor(key_id: str, region: str):
    lambda data: kms_client.encrypt(keyId=key_id, Plaintext=data)

def send(event, context, responseStatus, responseData, physicalResourceId=None, noEcho=False, reason=None):
    responseUrl = event['ResponseURL']

    responseBody = {
        'Status' : responseStatus,
        'Reason' : reason or "See the details in CloudWatch Log Stream: {}".format(context.log_stream_name),
        'PhysicalResourceId' : physicalResourceId or context.log_stream_name,
        'StackId' : event['StackId'],
        'RequestId' : event['RequestId'],
        'LogicalResourceId' : event['LogicalResourceId'],
        'NoEcho' : noEcho,
        'Data' : responseData
    }

    json_responseBody = json.dumps(responseBody)

    print("Response body:")
    print(json_responseBody)

    headers = {
        'content-type' : '',
        'content-length' : str(len(json_responseBody))
    }

    try:
        response = http.request('PUT', responseUrl, headers=headers, body=json_responseBody)
        print("Status code:", response.status)

    except Exception as e:

        print("send(..) failed executing http.request(..):", e)

def lambda_handler(event, context):
    try:
          send(event, context, "SUCCESS", { "content" : worker()})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        send(event, context, "FAILURE", { "message": str(e)} )
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
