import os
import json
import boto3
import urllib3
import base64


http = urllib3.PoolManager()


def worker():


    secrets_manager = boto3.client('secretsmanager')
    s3_client = boto3.client('s3')
    kms_client = boto3.client('kms')

    secret_arn = os.environ['SECRET_MANAGER_ARN']
    secret_value_response = secrets_manager.get_secret_value(SecretId=secret_arn)
    credentials = json.loads(secret_value_response['SecretString'])

    kms_fun = kms_encryptor(credentials["kms_id"], credentials["region"], kms_client)
    enc_pl = lambda x: kms_fun(credentials[x])
    pl = lambda x: credentials[x]



    output = f"""
LOCKER__SERVER__HOST=0.0.0.0
LOCKER__SERVER__PORT=8080
LOCKER__LOG__CONSOLE__ENABLED=true
LOCKER__LOG__CONSOLE__LEVEL=DEBUG
LOCKER__LOG__CONSOLE__LOG_FORMAT=default

LOCKER__DATABASE__USERNAME={pl("db_username")}
LOCKER__DATABASE__PASSWORD={enc_pl("db_password")}
LOCKER__DATABASE__HOST={pl("db_host")}
LOCKER__DATABASE__PORT=5432
LOCKER__DATABASE__DBNAME=locker

LOCKER__LIMIT__REQUEST_COUNT=100
LOCKER__LIMIT__DURATION=60

LOCKER__SECRETS__TENANT=hyperswitch
LOCKER__SECRETS__MASTER_KEY={enc_pl("master_key")}
LOCKER__SECRETS__LOCKER_PRIVATE_KEY={enc_pl("private_key")}
LOCKER__SECRETS__TENANT_PUBLIC_KEY={enc_pl("public_key")}

LOCKER__KMS__KEY_ID={pl("kms_id")}
LOCKER__KMS__REGION={pl("region")}
"""

    bucket_name = os.environ['ENV_BUCKET_NAME']
    filename = os.environ['ENV_FILE']

    s3_client.put_object(Bucket=bucket_name, Key=filename, Body=output.encode("utf-8"))
    




def kms_encryptor(key_id: str, region: str, kms_client):
    return lambda data: base64.b64encode(kms_client.encrypt(KeyId=key_id, Plaintext=data)["CiphertextBlob"]).decode("utf-8")

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
        return responseBody

    except Exception as e:

        print("send(..) failed executing http.request(..):", e)
        return {}

def lambda_handler(event, context):
    try:
        if event['RequestType'] == 'Create':
            try:
                worker()
                message = "Completed Successfully"
                status = "SUCCESS"
            except Exception as e:
                message = str(e)
                status = "FAILED"

            send(event, context, status, { "message": message})
        else:
            send(event, context, "SUCCESS", { "message" : "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        send(event, context, "FAILED", { "message": str(e)} )
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
