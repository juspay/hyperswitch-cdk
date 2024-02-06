import os
import json
import boto3
import urllib3
import base64
from dataclasses import dataclass

http = urllib3.PoolManager()


@dataclass
class SecretStore:
    secretArn: str
    secretName: str


def worker():

    dummy_val = "dummy_val"

    api_hash_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    secrets_manager = boto3.client('secretsmanager')
    kms_client = boto3.client('kms')

    secret_arn = os.environ['SECRET_MANAGER_ARN']
    secret_value_response = secrets_manager.get_secret_value(
        SecretId=secret_arn)
    credentials = json.loads(secret_value_response['SecretString'])

    kms_fun = kms_encryptor(
        credentials["kms_id"], credentials["region"], kms_client)

    def enc_pl(x): return kms_fun(credentials[x])
    def pl(x): return credentials[x]

    db_pass = enc_pl("db_password")
    master_key = enc_pl("master_key")
    admin_api_key = enc_pl("admin_api_key")
    jwt_secret = enc_pl("jwt_secret")

    locker_public_key = base64.b64encode(
        credentials["locker_public_key"].encode()).decode("utf-8")

    tenant_private_key = base64.b64encode(
        credentials["tenant_private_key"].encode()).decode("utf-8")

    dummy_val = kms_fun(dummy_val)
    kms_encrypted_api_hash_key = kms_fun(api_hash_key)

    secretval = {
        "db_pass": db_pass,
        "master_key": master_key,
        "admin_api_key": admin_api_key,
        "jwt_secret": jwt_secret,
        "dummy_val": dummy_val,
        "kms_encrypted_api_hash_key": kms_encrypted_api_hash_key,
        "locker_public_key": locker_public_key,
        "tenant_private_key": tenant_private_key,
    }

    secrets_manager.create_secret(
        Name="hyperswitch-kms-encrypted-store", SecretString=json.dumps(secretval))

    return SecretStore(
        secretArn=secretval["ARN"],
        secretName=secretval["Name"]
    )


def kms_encryptor(key_id: str, region: str, kms_client):
    return lambda data: base64.b64encode(kms_client.encrypt(KeyId=key_id, Plaintext=data)["CiphertextBlob"]).decode("utf-8")


def send(event, context, responseStatus, responseData, physicalResourceId=None, noEcho=False, reason=None):
    responseUrl = event['ResponseURL']

    responseBody = {
        'Status': responseStatus,
        'Reason': reason or "See the details in CloudWatch Log Stream: {}".format(context.log_stream_name),
        'PhysicalResourceId': physicalResourceId or context.log_stream_name,
        'StackId': event['StackId'],
        'RequestId': event['RequestId'],
        'LogicalResourceId': event['LogicalResourceId'],
        'NoEcho': noEcho,
        'Data': responseData
    }

    json_responseBody = json.dumps(responseBody)

    print("Response body:")
    print(json_responseBody)

    headers = {
        'content-type': '',
        'content-length': str(len(json_responseBody))
    }

    try:
        response = http.request(
            'PUT', responseUrl, headers=headers, body=json_responseBody)
        print("Status code:", response.status)
        return responseBody

    except Exception as e:

        print("send(..) failed executing http.request(..):", e)
        return {}


def lambda_handler(event, context):
    try:
        if event['RequestType'] == 'Create':
            try:
                secret = worker()
                message = "Completed Successfully"
                status = "SUCCESS"
            except Exception as e:
                message = str(e)
                status = "FAILED"

            send(event, context, status,
                 {
                     "message": message,
                     "secret_arn": secret.secretArn,
                     "secret_name": secret.secretName
                 })
        else:
            send(event, context, "SUCCESS", {"message": "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        send(event, context, "FAILED", {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
