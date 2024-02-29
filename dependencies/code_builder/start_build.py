import boto3
import os
import json
import urllib3

http = urllib3.PoolManager()

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


def lambda_handler(event, context):
    # get the details from the codebuild project from the environment variables and trigger the codebuild project
    if event['RequestType'] == 'Create':
        try:
            codebuild = boto3.client('codebuild')
            response = codebuild.start_build(
                projectName=os.environ['PROJECT_NAME'],
            )
            send(event, context, "SUCCESS", {"message": "CodeBuild project started"})
        except Exception as e:
            send(event, context, "FAILED", {"message": str(e)})
    else:
        send(event, context, "SUCCESS", {"message": "No action required"})

    return '{ "status": 200, "message": "success" }'
