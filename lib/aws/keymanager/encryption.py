import os
import json
import boto3
import urllib3
import base64

http = urllib3.PoolManager()


def worker():
    secrets_manager = boto3.client('secretsmanager')
    ssm_manager = boto3.client('ssm')

    kms_client = boto3.client('kms')

    secret_arn = os.environ['SECRET_MANAGER_ARN']
    secret_value_response = secrets_manager.get_secret_value(
        SecretId=secret_arn)
    credentials = json.loads(secret_value_response['SecretString'])

    kms_fun = kms_encryptor(
        credentials["kms_id"], credentials["region"], kms_client)

    def enc_pl(x): return kms_fun(credentials[x])
    def pl(x): return credentials[x]

    db_pass = enc_pl("db_pass")
    ca_cert = enc_pl("ca_cert")
    tls_key = enc_pl("tls_key")
    tls_cert = enc_pl("tls_cert")
    access_token = enc_pl("access_token")
    hash_context = enc_pl("hash_context")

    secretval = {
        "db_pass": db_pass,
        "ca_cert": ca_cert,
        "tls_key": tls_key,
        "tls_cert": tls_cert,
        "access_token": access_token,
        "hash_context": hash_context
    }

    for key in secretval:
        store_parameter(ssm_manager, key, secretval[key])


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


def store_parameter(ssm, key, value):
    ssm.put_parameter(Name="/keymanager/{}".format(key),
                      Value=value, Overwrite=True, Type='String', Tier='Advanced')


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

            send(event, context, status,
                 {
                     "message": message
                 })
        elif event['RequestType'] == 'Delete':
            keys = ["db_pass", "ca_cert", "tls_key", "tls_cert", "access_token", "hash_context"]
            ssm = boto3.client('ssm')
            for key in keys:
                parameter_name = "/keymanager/{}".format(key)
                try:
                    ssm.delete_parameter(Name=parameter_name)
                except:
                    print("Parameter {} doesn't exist.".format(parameter_name))

            send(event, context, "SUCCESS", {"message": "No action required"})
        else:
            send(event, context, "SUCCESS", {"message": "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        send(event, context, "FAILED", {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
