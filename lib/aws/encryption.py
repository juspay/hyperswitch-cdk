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
    locker_identifier1: str
    locker_identifier2: str
    locker_encryption_key1: str
    locker_encryption_key2: str
    locker_decryption_key1: str
    locker_decryption_key2: str
    vault_encryption_key: str
    vault_private_key: str
    tunnel_private_key: str
    rust_locker_encryption_key: str
    paypal_onboard_client_id: str
    paypal_onboard_client_secret: str
    paypal_onboard_partner_id: str


def worker():

    dummy_val = "dummy_val"

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
    rust_locker_encryption_key = enc_pl("rust_locker_encryption_key")

    locker_identifier1 = kms_fun(dummy_val)
    locker_identifier2 = kms_fun(dummy_val)
    locker_encryption_key1 = kms_fun(dummy_val)
    locker_decryption_key1 = kms_fun(dummy_val)
    locker_encryption_key2 = kms_fun(dummy_val)
    locker_decryption_key2 = kms_fun(dummy_val)
    vault_encryption_key = kms_fun(dummy_val)
    vault_private_key = kms_fun(dummy_val)
    tunnel_private_key = kms_fun(dummy_val)
    paypal_onboard_client_id = kms_fun(dummy_val)
    paypal_onboard_client_secret = kms_fun(dummy_val)
    paypal_onboard_partner_id = kms_fun(dummy_val)

    return KmsSecrets(db_pass,
                      master_key,
                      admin_api_key,
                      jwt_secret,
                      locker_identifier1,
                      locker_identifier2,
                      locker_encryption_key1,
                      locker_encryption_key2,
                      locker_decryption_key1,
                      locker_decryption_key2,
                      vault_encryption_key,
                      vault_private_key,
                      tunnel_private_key,
                      rust_locker_encryption_key,
                      paypal_onboard_client_id,
                      paypal_onboard_client_secret,
                      paypal_onboard_partner_id)


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
                     "kms_locker_identifier1": kms_secrets.locker_identifier1,
                     "kms_locker_identifier2": kms_secrets.locker_identifier2,
                     "kms_locker_encryption_key1": kms_secrets.locker_encryption_key1,
                     "kms_locker_encryption_key2": kms_secrets.locker_encryption_key2,
                     "kms_locker_decryption_key1": kms_secrets.locker_decryption_key1,
                     "kms_locker_decryption_key2": kms_secrets.locker_decryption_key2,
                     "kms_vault_private_key": kms_secrets.vault_private_key,
                     "kms_vault_encryption_key": kms_secrets.vault_encryption_key,
                     "kms_tunnel_private_key": kms_secrets.tunnel_private_key,
                     "rust_locker_encryption_key": kms_secrets.rust_locker_encryption_key,
                     "kms_connector_onboarding_paypal_client_id": kms_secrets.paypal_onboard_client_id,
                     "kms_connector_onboarding_paypal_partner_id": kms_secrets.paypal_onboard_partner_id,
                     "kms_connector_onboarding_paypal_client_secret": kms_secrets.paypal_onboard_client_secret,
                 })
        else:
            send(event, context, "SUCCESS", {"message": "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        send(event, context, "FAILED", {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
