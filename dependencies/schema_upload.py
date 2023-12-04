import boto3
import urllib3
import json

# Constants for response status
SUCCESS = "SUCCESS"
FAILED = "FAILED"

# Initialize HTTP and S3 clients
http = urllib3.PoolManager()
s3 = boto3.client('s3')

def send_response(event, context, response_status, response_data, physical_resource_id=None, reason=None):
    """Send a response to the CloudFormation stack."""
    response_body = {
        'Status': response_status,
        'Reason': reason or f"See the details in CloudWatch Log Stream: {context.log_stream_name}",
        'PhysicalResourceId': physical_resource_id or context.log_stream_name,
        'StackId': event['StackId'],
        'RequestId': event['RequestId'],
        'LogicalResourceId': event['LogicalResourceId'],
        'Data': response_data
    }

    json_response_body = json.dumps(response_body)
    print("Response body:", json_response_body)

    try:
        response = http.request('PUT', event['ResponseURL'], body=json_response_body, headers={'content-type': '', 'content-length': str(len(json_response_body))})
        print("Status code:", response.status)
    except Exception as e:
        print("Error sending response:", e)

def upload_file_to_s3(url, bucket, key):
    """Upload a file from a URL to an S3 bucket."""
    try:
        with http.request('GET', url, preload_content=False) as response, open('/tmp/tempfile', 'wb') as out_file:
            out_file.write(response.data)
        s3.upload_file('/tmp/tempfile', bucket, key)
    except Exception as e:
        print(f"Error uploading file {url} to S3: {e}")
        raise

def lambda_handler(event, context):
    """AWS Lambda handler function."""
    try:
        if event['RequestType'] == 'Create':
            bucket_name = "{{BUCKET_NAME}}"  # Replace with your bucket name
            upload_file_to_s3("https://hyperswitch-bucket.s3.amazonaws.com/migration_runner.zip", bucket_name, "migration_runner.zip")
            upload_file_to_s3("https://hyperswitch-bucket.s3.amazonaws.com/schema.sql", bucket_name, "schema.sql")
            upload_file_to_s3("https://hyperswitch-bucket.s3.amazonaws.com/locker-schema.sql", bucket_name, "locker-schema.sql")
            send_response(event, context, SUCCESS, {"message": "Files uploaded successfully"})
        else:
            send_response(event, context, SUCCESS, {"message": "No action required"})
    except Exception as e:
        send_response(event, context, FAILED, {"message": str(e)})
        return {"status": 500, "message": str(e)}

    return {"status": 200, "message": "Success"}