
import os
import json
import boto3
import urllib3

http = urllib3.PoolManager()


def worker():
    imagebuilder = boto3.client("imagebuilder")

    envoy_arn = os.environ['envoy_image_pipeline_arn']
    squid_arn = os.environ['squid_image_pipeline_arn']
    base_arn = os.environ['base_image_pipeline_arn']

    imagebuilder.start_image_pipeline_execution(
        imagePipelineArn=envoy_arn)

    imagebuilder.start_image_pipeline_execution(
        imagePipelineArn=squid_arn)

    imagebuilder.start_image_pipeline_execution(
        imagePipelineArn=base_arn)


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
    if event['RequestType'] == 'Create':
        try:
            worker()
            message = "Completed Successfully"
            status = "SUCCESS"
            send(event, context, status,
                 {
                     "message": message
                 })
        except Exception as e:
            send(event, context, "FAILED", {"message": str(e)})
    else:
        send(event, context, "SUCCESS", {"message": "No action required"})

    send(event, context, "SUCCESS", {"message": "No action required"})
