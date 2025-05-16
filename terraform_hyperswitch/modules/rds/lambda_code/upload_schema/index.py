import boto3
import urllib3
import json
import os

SUCCESS = "SUCCESS"
FAILED = "FAILED"

http = urllib3.PoolManager()

def send(event, context, response_status, response_data, physical_resource_id=None, no_echo=False, reason=None):
    response_url = event['ResponseURL']

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

    print("Response body:")
    print(json_response_body)

    headers = {
        'content-type': '',
        'content-length': str(len(json_response_body))
    }

    try:
        response = http.request('PUT', response_url, headers=headers, body=json_response_body)
        print("Status code:", response.status)

    except Exception as e:
        print("send(..) failed executing http.request(..):", e)

def upload_file_from_url(url, bucket, key):
    s3 = boto3.client('s3')
    # http is already initialized globally
    try:
        with http.request('GET', url, preload_content=False) as resp, open('/tmp/tempfile', 'wb') as outfile:
            if resp.status != 200:
                raise Exception(f"Failed to download {url}, status code: {resp.status}")
            # Stream download to a temporary file
            for chunk in resp.stream(32*1024): # 32KB chunks
                outfile.write(chunk)
        
        # Upload from the temporary file
        s3.upload_file('/tmp/tempfile', bucket, key)
        print(f"Successfully uploaded {url} to s3://{bucket}/{key}")
    
    except Exception as e:
        print(f"Error uploading {url} to s3://{bucket}/{key}: {e}")
        raise
    finally:
        if os.path.exists('/tmp/tempfile'):
            os.remove('/tmp/tempfile')


def lambda_handler(event, context):
    print("Received event:", json.dumps(event))
    
    # Get SCHEMA_BUCKET_NAME from environment variables
    schema_bucket_name = os.environ.get('SCHEMA_BUCKET_NAME')
    if not schema_bucket_name:
        error_message = "SCHEMA_BUCKET_NAME environment variable not set."
        print(error_message)
        if event.get('RequestType') != 'Delete': # Only send response if not a delete event that failed due to missing env var
             send(event, context, FAILED, {"message": error_message})
        return # Or raise an exception

    # These URLs are from the CDK code
    # Note: The CDK code had placeholders like ${process.env.CDK_DEFAULT_ACCOUNT} in bucket names
    # Here, schema_bucket_name is passed directly.
    migration_runner_url = "https://raw.githubusercontent.com/juspay/hyperswitch-cdk/main/lib/aws/migrations/migration_runner.zip"
    schema_sql_url = "https://raw.githubusercontent.com/juspay/hyperswitch-cdk/main/lib/aws/migrations/v1.113.0/schema.sql" # Assuming latest version from CDK
    locker_schema_sql_url = "https://raw.githubusercontent.com/juspay/hyperswitch-cdk/main/lib/aws/migrations/locker-schema.sql"

    try:
        if event['RequestType'] == 'Create' or event['RequestType'] == 'Update':
            print(f"Attempting to upload files to bucket: {schema_bucket_name}")
            upload_file_from_url(migration_runner_url, schema_bucket_name, "migration_runner.zip")
            upload_file_from_url(schema_sql_url, schema_bucket_name, "schema.sql")
            upload_file_from_url(locker_schema_sql_url, schema_bucket_name, "locker-schema.sql")
            send(event, context, SUCCESS, {"message": "Files uploaded successfully"})
        elif event['RequestType'] == 'Delete':
            # Optionally, add logic to delete files from S3 on stack deletion
            print("Delete event received. No action configured for S3 file deletion.")
            send(event, context, SUCCESS, {"message": "Delete event: No action taken for S3 files."})
        else:
            send(event, context, SUCCESS, {"message": "Unknown event type, no action taken."})
            
    except Exception as e:
        error_msg = f"Error during lambda execution: {str(e)}"
        print(error_msg)
        send(event, context, FAILED, {"message": error_msg})
        # raise # Optionally re-raise to ensure Lambda execution fails visibly in CloudWatch

    return {"status": "Lambda execution finished."} # General return for Lambda
