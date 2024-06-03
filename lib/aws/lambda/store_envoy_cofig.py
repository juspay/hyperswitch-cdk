import boto3
import urllib3
import json
import os

SUCCESS = "SUCCESS"
FAILED = "FAILED"

http = urllib3.PoolManager()

data = {{envoy_config}}
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

def upload_file(url, bucket, key):
    s3=boto3.client('s3')
    s3.Bucket(bucket).put_object(Key=key, Body=data.encode('utf-8'))

def lambda_handler(event, context):
    try:
        # Call the upload_file_from_url function to upload two files to S3
        if event['RequestType'] == 'Create':
          upload_file(os.environ['BUCKET'], os.environ['KEY'])
          send(event, context, SUCCESS, { "message" : "Files uploaded successfully"})
        else:
          send(event, context, SUCCESS, { "message" : "No action required"})
    except Exception as e:
        send(event, context, FAILED, {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'