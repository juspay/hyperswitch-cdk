import json
import boto3
import os
import base64

# Variables from environment
SECRET_MANAGER_ARN = os.environ.get('SECRET_MANAGER_ARN') # ARN of the KeymanagerKmsDataSecret
ENV_BUCKET_NAME = os.environ.get('ENV_BUCKET_NAME')
ENV_FILE_KEY = os.environ.get('ENV_FILE') # Key for the .env file in S3, e.g., "keymanager.env"

SUCCESS = "SUCCESS"
FAILED = "FAILED"

def send(event, context, response_status, response_data, physical_resource_id=None, no_echo=False, reason=None):
    response_url = event.get('ResponseURL')
    if not response_url:
        print("No ResponseURL found in event. Skipping CFN response.")
        return

    print(f"Response URL: {response_url}")
    response_body = {
        'Status': response_status,
        'Reason': reason or "See the details in CloudWatch Log Stream: {}".format(context.log_stream_name),
        'PhysicalResourceId': physical_resource_id or context.log_stream_name,
        'StackId': event['StackId'],
        'RequestId': event['RequestId'],
        'LogicalResourceId': event['LogicalResourceId'],
        'NoEcho': no_echo,
        'Data': response_data
    }
    json_response_body = json.dumps(response_body)
    print("Response body:", json_response_body)
    headers = { 'content-type': '', 'content-length': str(len(json_response_body)) }
    try:
        import urllib3
        http = urllib3.PoolManager()
        response = http.request('PUT', response_url, headers=headers, body=json_response_body)
        print("Status code:", response.status)
    except Exception as e:
        print("send(..) failed executing http.request(..):", e)
        raise

def get_secret(secret_name):
    client = boto3.client('secretsmanager')
    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    except Exception as e:
        print(f"Error getting secret {secret_name}: {e}")
        raise e
    else:
        if 'SecretString' in get_secret_value_response:
            return json.loads(get_secret_value_response['SecretString'])
        else:
            return json.loads(base64.b64decode(get_secret_value_response['SecretBinary']))

def encrypt_value(kms_client, key_id, plain_text_value):
    if not plain_text_value: return ""
    try:
        response = kms_client.encrypt(KeyId=key_id, Plaintext=str(plain_text_value).encode('utf-8'))
        return base64.b64encode(response['CiphertextBlob']).decode('utf-8')
    except Exception as e:
        print(f"Error encrypting value: {e}")
        raise

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    
    if not all([SECRET_MANAGER_ARN, ENV_BUCKET_NAME, ENV_FILE_KEY]):
        error_msg = "Missing env vars: SECRET_MANAGER_ARN, ENV_BUCKET_NAME, ENV_FILE_KEY"
        print(error_msg)
        if event.get('RequestType') != 'Delete': send(event, context, FAILED, {"message": error_msg})
        return {"status": "FAILED", "error": error_msg}

    kms_client = boto3.client('kms')
    s3_client = boto3.client('s3')

    try:
        secrets = get_secret(SECRET_MANAGER_ARN)
        
        kms_key_id_for_km = secrets.get('kms_id') # KMS Key ID for Keymanager data encryption
        if not kms_key_id_for_km: raise ValueError("kms_id not found in secret")

        # Values from KeymanagerKmsDataSecret
        db_username = secrets.get('db_username', '')
        db_password_plain = secrets.get('db_password', '')
        db_host = secrets.get('db_host', '')
        master_key_plain = secrets.get('master_key', '')
        keymanager_name = secrets.get('keymanager_name', 'default_km')
        
        # TLS certs are stored directly in the .env file, not typically KMS encrypted for the .env itself.
        # The .env file as a whole is S3 encrypted.
        tls_key_pem = secrets.get('tls_key', '')
        tls_cert_pem = secrets.get('tls_cert', '')
        ca_cert_pem = secrets.get('ca_cert', '')

        encrypted_db_password = encrypt_value(kms_client, kms_key_id_for_km, db_password_plain)
        encrypted_master_key = encrypt_value(kms_client, kms_key_id_for_km, master_key_plain)

        # Construct .env content for Keymanager application
        # This needs to match what the Keymanager application expects.
        env_content = f"""
KEY_MANAGER_NAME={keymanager_name}
DATABASE_URL=postgres://{db_username}:{db_password_plain}@{db_host}/keymanager_{keymanager_name.lower().replace('-', '_')}
ENCRYPTED_MASTER_KEY={encrypted_master_key}
TLS_KEY="{tls_key_pem.replace(chr(10), chr(92)+chr(10))}"
TLS_CERT="{tls_cert_pem.replace(chr(10), chr(92)+chr(10))}"
CA_CERT="{ca_cert_pem.replace(chr(10), chr(92)+chr(10))}"
# Add other necessary env variables for Keymanager
# Example: KMS_KEY_ID={kms_key_id_for_km} # If app needs to know the KMS key for decryption
# REGION={secrets.get('region', '')}
"""
        print(f"Generated .env content for Keymanager {keymanager_name}:\n{env_content}")

        s3_client.put_object(
            Bucket=ENV_BUCKET_NAME, Key=ENV_FILE_KEY, Body=env_content.encode('utf-8'),
            ServerSideEncryption='aws:kms', SSEKMSKeyId=kms_key_id_for_km
        )
        print(f"Successfully uploaded encrypted .env for Keymanager to s3://{ENV_BUCKET_NAME}/{ENV_FILE_KEY}")
        
        output_data = { "message": f"Keymanager {keymanager_name} secrets encrypted and .env uploaded.", "s3_key": ENV_FILE_KEY }
        if event.get('RequestType') != 'Delete': send(event, context, SUCCESS, output_data)

    except Exception as e:
        error_msg = f"Error during Keymanager secrets processing: {str(e)}"
        print(error_msg)
        if event.get('RequestType') != 'Delete': send(event, context, FAILED, {"message": error_msg})
        # raise

    return {"status": "Lambda execution finished."}
