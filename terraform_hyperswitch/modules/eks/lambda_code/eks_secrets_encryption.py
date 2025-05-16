import json
import boto3
import os
import base64

# Variables from environment
SECRET_MANAGER_ARN = os.environ.get('SECRET_MANAGER_ARN') # ARN of the KmsDataSecret for Hyperswitch EKS

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
            decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
            return json.loads(decoded_binary_secret)

def encrypt_value(kms_client, key_id, plain_text_value):
    if not plain_text_value:
        return "" # Return empty string for empty input
    try:
        response = kms_client.encrypt(
            KeyId=key_id,
            Plaintext=str(plain_text_value).encode('utf-8') # Ensure it's string then encode
        )
        return base64.b64encode(response['CiphertextBlob']).decode('utf-8')
    except Exception as e:
        print(f"Error encrypting value: {e}")
        raise

def store_secret_in_ssm(ssm_client, name, value, description="Encrypted secret for Hyperswitch", key_id="alias/aws/ssm", overwrite=True):
    try:
        ssm_client.put_parameter(
            Name=name,
            Description=description,
            Value=value,
            Type='SecureString', # Use SecureString for sensitive data
            Overwrite=overwrite,
            KeyId=key_id # KMS key for SSM SecureString encryption (can be aws/ssm or a custom key)
        )
        print(f"Successfully stored/updated parameter: {name}")
    except Exception as e:
        print(f"Error storing parameter {name}: {e}")
        raise

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    
    if not SECRET_MANAGER_ARN:
        error_msg = "SECRET_MANAGER_ARN environment variable not set."
        print(error_msg)
        if event.get('RequestType') != 'Delete':
            send(event, context, FAILED, {"message": error_msg})
        return {"status": "FAILED", "error": error_msg}

    kms_client = boto3.client('kms')
    ssm_client = boto3.client('ssm')

    try:
        secrets_to_encrypt = get_secret(SECRET_MANAGER_ARN)
        
        kms_key_id_for_app = secrets_to_encrypt.get('kms_id') # This is the Hyperswitch App KMS Key ID
        if not kms_key_id_for_app:
            raise ValueError("kms_id (for Hyperswitch App) not found in secret")

        # Secrets that need to be encrypted and stored in SSM for Helm chart
        # Based on KmsSecrets class and Hyperswitch Helm chart values
        # The names of SSM parameters should match what the Helm chart expects or how they are referenced.
        # Using a common prefix for Hyperswitch related SSM parameters.
        ssm_prefix = "/hyperswitch" 

        params_to_store = {
            f"{ssm_prefix}/admin-api-key": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("admin_api_key")),
            f"{ssm_prefix}/jwt-secret": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("jwt_secret")),
            f"{ssm_prefix}/db-pass": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("db_password")),
            f"{ssm_prefix}/master-key": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("master_key")),
            f"{ssm_prefix}/locker-public-key": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("locker_public_key")),
            f"{ssm_prefix}/tenant-private-key": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("tenant_private_key")),
            # Dummy values from CDK's KmsSecrets class - these should ideally be actual secrets or removed if not used
            f"{ssm_prefix}/dummy-val": encrypt_value(kms_client, kms_key_id_for_app, "dummy_secret_value"), # Placeholder for many dummy vals
            f"{ssm_prefix}/kms-encrypted-api-hash-key": encrypt_value(kms_client, kms_key_id_for_app, "some_api_hash_key"), # Placeholder
            f"{ssm_prefix}/google-pay-root-signing-keys": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("google_pay_root_signing_keys", "dummy_gpay_keys")),
            f"{ssm_prefix}/paze-private-key": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("paze_private_key", "dummy_paze_key")),
            f"{ssm_prefix}/paze-private-key-passphrase": encrypt_value(kms_client, kms_key_id_for_app, secrets_to_encrypt.get("paze_private_key_passphrase", "dummy_paze_pass"))
        }
        
        # Add other specific secrets from KmsSecrets class if they are not just "dummy-val"
        # For example: recon_admin_api_key, forex_api_key, apple_pay related keys etc.
        # These would need to be present in the HyperswitchKmsDataSecret in Secrets Manager.

        for param_name, param_value in params_to_store.items():
            if param_value: # Only store if encryption didn't return empty (e.g. for empty input)
                 # Using the application's KMS key (kms_key_id_for_app) to encrypt the SSM SecureString value itself.
                 # This means the EKS service account role needs decrypt access to this KMS key to read these SSM params.
                store_secret_in_ssm(ssm_client, param_name, param_value, key_id=kms_key_id_for_app)
            else:
                print(f"Skipping SSM parameter storage for {param_name} due to empty encrypted value.")


        output_data = {
            "message": "Secrets encrypted and stored in SSM Parameter Store.",
            "ssm_parameters_prefix": ssm_prefix,
            "parameters_stored": list(params_to_store.keys())
        }
        if event.get('RequestType') != 'Delete':
            send(event, context, SUCCESS, output_data)

    except Exception as e:
        error_msg = f"Error during EKS secrets processing or SSM storage: {str(e)}"
        print(error_msg)
        if event.get('RequestType') != 'Delete':
            send(event, context, FAILED, {"message": error_msg})
        # raise # Re-raise to ensure Lambda execution fails visibly

    return {"status": "Lambda execution finished."}
