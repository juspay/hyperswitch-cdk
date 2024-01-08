import os
import json
import boto3
import urllib3
import base64


http = urllib3.PoolManager()


def worker():

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
    kms_key_id = base64.b64encode(credentials["kms_id"])
    kms_region = base64.b64encode(credentials["region"])
    return db_pass, master_key, admin_api_key, jwt_secret, kms_key_id, kms_region


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
                db_pass, master_key, admin_api_key, jwt_secret, kms_key_id, kms_region = worker()
                message = "Completed Successfully"
                status = "SUCCESS"
            except Exception as e:
                message = str(e)
                status = "FAILED"

            send(event, context, status, {
                "message": message, "db_pass": db_pass, "master_key": master_key, "admin_api_key": admin_api_key, "jwt_secret": jwt_secret, "kms_key_id": kms_key_id, "kms_region": kms_region})
        else:
            send(event, context, "SUCCESS", {"message": "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        send(event, context, "FAILED", {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
