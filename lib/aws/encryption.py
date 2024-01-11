import os
import json
import boto3
import urllib3
import base64
from dataclasses import dataclass

http = urllib3.PoolManager()


@dataclass
class KmsSecrets:
    db_pass: str
    master_key: str
    admin_api_key: str
    jwt_secret: str
    dummy_val: str
    kms_id: str
    kms_region: str
    api_hash_key: str


def worker():

    dummy_val = "dummy_val"

    api_hash_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    secrets_manager = boto3.client('secretsmanager')
    kms_client = boto3.client('kms')

    secret_arn = os.environ['SECRET_MANAGER_ARN']
    secret_value_response = secrets_manager.get_secret_value(
        SecretId=secret_arn)
    credentials = json.loads(secret_value_response['SecretString'])

    kms_fun_secret = kms_encryptor_secret(
        credentials["kms_id"], credentials["region"], kms_client)

    kms_fun = kms_encryptor(
        credentials["kms_id"], credentials["region"], kms_client)

    def enc_pl_secret(x): return kms_fun_secret(credentials[x])
    def enc_pl(x): return kms_fun(credentials[x])
    def pl(x): return credentials[x]

    db_pass = enc_pl("db_password")
    master_key = enc_pl_secret("master_key")
    admin_api_key = enc_pl_secret("admin_api_key")
    jwt_secret = enc_pl_secret("jwt_secret")
    kms_id = base64.b64encode(credentials["kms_id"].encode()).decode("utf-8")
    kms_region = base64.b64encode(
        credentials["region"].encode()).decode("utf-8")

    dummy_val = kms_fun_secret(dummy_val)
    kms_encrypted_api_hash_key = kms_fun_secret(api_hash_key)

    return KmsSecrets(db_pass,
                      master_key,
                      admin_api_key,
                      jwt_secret,
                      dummy_val,
                      kms_id,
                      kms_region,
                      kms_encrypted_api_hash_key
                      )


def kms_encryptor(key_id: str, region: str, kms_client):
    return lambda data: base64.b64encode(kms_client.encrypt(KeyId=key_id, Plaintext=data)["CiphertextBlob"]).decode("utf-8")

def kms_encryptor_secret(key_id: str, region: str, kms_client):
    return lambda data: base64.b64encode(base64.b64encode(kms_client.encrypt(KeyId=key_id, Plaintext=data)["CiphertextBlob"])).decode("utf-8")


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
                kms_secrets = worker()
                message = "Completed Successfully"
                status = "SUCCESS"
            except Exception as e:
                message = str(e)
                status = "FAILED"

            send(event, context, status,
                 {
                     "message": message,
                     "db_pass": kms_secrets.db_pass,
                     "master_key": kms_secrets.master_key,
                     "admin_api_key": kms_secrets.admin_api_key,
                     "jwt_secret": kms_secrets.jwt_secret,
                     "kms_id": kms_secrets.kms_id,
                     "kms_region": kms_secrets.kms_region,
                     "dummy_val": kms_secrets.dummy_val,
                     "api_hash_key": kms_secrets.api_hash_key,
                 })
        else:
            send(event, context, "SUCCESS", {"message": "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        send(event, context, "FAILED", {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
