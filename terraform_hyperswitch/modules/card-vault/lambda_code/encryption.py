import json
import boto3
import os
import base64

# Variables from environment
SECRET_MANAGER_ARN = os.environ.get('SECRET_MANAGER_ARN')
ENV_BUCKET_NAME = os.environ.get('ENV_BUCKET_NAME')
ENV_FILE_KEY = os.environ.get('ENV_FILE') # Key for the .env file in S3, e.g., "locker.env"

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

    headers = {
        'content-type': '',
        'content-length': str(len(json_response_body))
    }

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
            secret = get_secret_value_response['SecretString']
            return json.loads(secret)
        else:
            # Handle binary secret if needed, though CDK stores JSON string
            decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
            return json.loads(decoded_binary_secret)


def encrypt_value(kms_client, key_id, plain_text_value):
    if not plain_text_value: # Handle empty or None values gracefully
        return ""
    try:
        response = kms_client.encrypt(
            KeyId=key_id,
            Plaintext=plain_text_value.encode('utf-8')
        )
        return base64.b64encode(response['CiphertextBlob']).decode('utf-8')
    except Exception as e:
        print(f"Error encrypting value: {e}")
        raise


def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    
    if not all([SECRET_MANAGER_ARN, ENV_BUCKET_NAME, ENV_FILE_KEY]):
        error_msg = "Missing one or more environment variables: SECRET_MANAGER_ARN, ENV_BUCKET_NAME, ENV_FILE_KEY"
        print(error_msg)
        if event.get('RequestType') != 'Delete':
             send(event, context, FAILED, {"message": error_msg})
        return {"status": "FAILED", "error": error_msg}

    kms_client = boto3.client('kms')
    s3_client = boto3.client('s3')

    try:
        secrets = get_secret(SECRET_MANAGER_ARN)
        
        kms_key_id = secrets.get('kms_id') # This is the KMS Key ID for encryption
        if not kms_key_id:
            raise ValueError("kms_id not found in secret")

        # Values to be encrypted and put into the .env file
        # These keys match the structure of LockerKmsDataSecret in CDK
        db_username = secrets.get('db_username', '')
        db_password = secrets.get('db_password', '') # Plain text from secret
        db_host = secrets.get('db_host', '')
        master_key_plain = secrets.get('master_key', '') # Plain text from secret
        locker_private_key = secrets.get('private_key', '') # Plain text RSA private key
        tenant_public_key = secrets.get('public_key', '') # Plain text RSA public key
        
        # Encrypt sensitive values
        encrypted_db_password = encrypt_value(kms_client, kms_key_id, db_password)
        encrypted_master_key = encrypt_value(kms_client, kms_key_id, master_key_plain)
        # RSA keys are typically stored as-is (PEM format) and not further KMS encrypted for the .env file itself.
        # The .env file itself will be S3 encrypted.
        # If they need to be KMS encrypted, add:
        # encrypted_locker_private_key = encrypt_value(kms_client, kms_key_id, locker_private_key)
        # encrypted_tenant_public_key = encrypt_value(kms_client, kms_key_id, tenant_public_key)

        env_content = f"""
DATABASE_URL=postgres://{db_username}:{db_password}@{db_host}/locker # Using plain db_password for direct DB connection string
ENCRYPTED_MASTER_KEY={encrypted_master_key}
LOCKER_PRIVATE_KEY="{locker_private_key.replace(chr(10), chr(92)+chr(10))}"
TENANT_PUBLIC_KEY="{tenant_public_key.replace(chr(10), chr(92)+chr(10))}"
# Add other necessary env variables here
# Example: KMS_KEY_ID={kms_key_id} # If app needs to know the KMS key for decryption
# REGION={secrets.get('region', '')}
"""
        # Note: The original CDK's encryption.py for LockerEc2 seems to create an env file
        # that is then used by user-data.sh. The user-data.sh script sources this file.
        # The exact format and content of this .env file needs to match what the application expects.
        # The above is an interpretation based on common .env patterns and CDK secret structure.

        print(f"Generated .env content (sensitive values are KMS encrypted or plain for direct use like DB_URL):\n{env_content}")

        s3_client.put_object(
            Bucket=ENV_BUCKET_NAME,
            Key=ENV_FILE_KEY,
            Body=env_content.encode('utf-8'),
            ServerSideEncryption='aws:kms', # This uses the S3 bucket's default KMS key if configured, or specified key
            SSEKMSKeyId=kms_key_id # Explicitly use the locker's KMS key for this object
        )
        print(f"Successfully uploaded encrypted .env file to s3://{ENV_BUCKET_NAME}/{ENV_FILE_KEY}")
        
        # Data to return to CloudFormation (if this Lambda is a Custom Resource)
        # For Terraform null_resource, this data isn't directly consumed by TF state,
        # but can be useful for logging or if the CFN response URL was real.
        output_data = {
            "message": "Secrets encrypted and .env file uploaded to S3.",
            "s3_bucket": ENV_BUCKET_NAME,
            "s3_key": ENV_FILE_KEY
        }
        if event.get('RequestType') != 'Delete':
            send(event, context, SUCCESS, output_data)

    except Exception as e:
        error_msg = f"Error during secrets processing or S3 upload: {str(e)}"
        print(error_msg)
        if event.get('RequestType') != 'Delete':
            send(event, context, FAILED, {"message": error_msg})
        # raise # Re-raise to ensure Lambda execution fails visibly

    return {"status": "Lambda execution finished."}
