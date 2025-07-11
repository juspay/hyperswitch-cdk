import os
import json
import boto3
import base64

def worker():
    dummy_val = "dummy_val"
    api_hash_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

    secrets_manager = boto3.client('secretsmanager')
    ssm_manager = boto3.client('ssm')
    kms_client = boto3.client('kms')

    secret_arn = os.environ['SECRET_MANAGER_ARN']
    secret_value_response = secrets_manager.get_secret_value(SecretId=secret_arn)
    credentials = json.loads(secret_value_response['SecretString'])

    kms_fun = kms_encryptor(credentials["kms_id"], credentials["region"], kms_client)

    def enc_pl(x): return kms_fun(credentials[x])

    db_pass = enc_pl("db_password")
    master_key = enc_pl("master_key")
    admin_api_key = enc_pl("admin_api_key")
    jwt_secret = enc_pl("jwt_secret")
    locker_public_key = enc_pl("locker_public_key")
    tenant_private_key = enc_pl("tenant_private_key")

    paze_private_key = kms_fun("PAZE_PRIVATE_KEY")
    paze_private_key_passphrase = kms_fun("PAZE_PRIVATE_KEY_PASSPHRASE")
    google_pay_root_signing_keys = kms_fun("GOOGLE_PAY_ROOT_SIGNING_KEYS")

    dummy_val = kms_fun(dummy_val)
    kms_encrypted_api_hash_key = kms_fun(api_hash_key)

    secretval = {
        "db-pass": db_pass,
        "master-key": master_key,
        "admin-api-key": admin_api_key,
        "jwt-secret": jwt_secret,
        "dummy-val": dummy_val,
        "kms-encrypted-api-hash-key": kms_encrypted_api_hash_key,
        "locker-public-key": locker_public_key,
        "tenant-private-key": tenant_private_key,
        "paze-private-key": paze_private_key,
        "paze-private-key-passphrase": paze_private_key_passphrase,
        "google-pay-root-signing-keys": google_pay_root_signing_keys,
    }

    for key in secretval:
        store_parameter(ssm_manager, key, secretval[key])

def kms_encryptor(key_id: str, region: str, kms_client):
    return lambda data: base64.b64encode(kms_client.encrypt(KeyId=key_id, Plaintext=data)["CiphertextBlob"]).decode("utf-8")

def store_parameter(ssm, key, value):
    ssm.put_parameter(
        Name="/hyperswitch/{}".format(key),
        Value=value,
        Overwrite=True,
        Type='String',
        Tier='Advanced'
    )

def lambda_handler(event, context):
    print("Received event:", json.dumps(event, indent=2))

    # Check if RequestType is Create (for backwards compatibility)
    request_type = event.get('RequestType', 'Create')

    if request_type == 'Create':
        try:
            worker()
            result_data = {"message": "KMS encryption and parameter storage completed successfully"}

            print("Operation completed successfully:", result_data)

            return {
                'statusCode': 200,
                'body': json.dumps(result_data)
            }
        except Exception as e:
            error_message = str(e)
            print("Error occurred:", error_message)

            # Raise exception to mark Terraform resource as failed
            raise Exception(f"Lambda execution failed: {error_message}")
    else:
        # Skip execution for other request types
        result_data = {"message": "No action required"}
        return {
            'statusCode': 200,
            'body': json.dumps(result_data)
        }
