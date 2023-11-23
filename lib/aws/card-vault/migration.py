import boto3
import urllib3
import json

SUCCESS = "SUCCESS"
FAILED = "FAILED"

http = urllib3.PoolManager()


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

    except Exception as e:

        print("send(..) failed executing http.request(..):", e)

def upload_file_from_url(url, bucket, key):
    s3=boto3.client('s3')
    http=urllib3.PoolManager()
    s3.upload_fileobj(http.request('GET', url,preload_content=False), bucket, key)
    s3.upload_fileobj

def lambda_handler(event, context):
    try:
        # Call the upload_file_from_url function to upload two files to S3
        if event['RequestType'] == 'Create':
          upload_file_from_url("https://hyperswitch-locker-bucket.s3.amazonaws.com/migration_runner.zip", "locker-schema-{{ACCOUNT}}-{{REGION}}", "migration_runner.zip")
          upload_file_from_url("https://hyperswitch-locker-bucket.s3.amazonaws.com/schema.sql", "locker-schema-{{ACCOUNT}}-{{REGION}}", "locker-schema.sql")
          send(event, context, SUCCESS, { "message" : "Files uploaded successfully"})
        else:
          send(event, context, SUCCESS, { "message" : "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        # Handle exceptions and return an error message
        send(event, context, FAILED, {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
