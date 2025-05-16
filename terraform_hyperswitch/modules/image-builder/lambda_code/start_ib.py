import json
import boto3
import os

SUCCESS = "SUCCESS"
FAILED = "FAILED"

def send(event, context, response_status, response_data, physical_resource_id=None, no_echo=False, reason=None):
    response_url = event['ResponseURL']
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
        # Using boto3 to make the PUT request for better error handling and control
        http_client = boto3.client('s3') # Actually, this should be a generic http client or urllib3
                                        # For CFN custom resources, direct HTTP PUT is typical.
                                        # Reverting to urllib3 as it's common for this.
        import urllib3
        http = urllib3.PoolManager()
        response = http.request('PUT', response_url, headers=headers, body=json_response_body)
        print("Status code:", response.status)

    except Exception as e:
        print("send(..) failed executing http.request(..):", e)
        raise # Re-raise to ensure Lambda execution fails if CFN response can't be sent

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    imagebuilder = boto3.client('imagebuilder')
    
    envoy_pipeline_arn = os.environ.get('envoy_image_pipeline_arn')
    squid_pipeline_arn = os.environ.get('squid_image_pipeline_arn')
    base_pipeline_arn = os.environ.get('base_image_pipeline_arn')
    
    pipelines_to_start = []
    if envoy_pipeline_arn:
        pipelines_to_start.append(envoy_pipeline_arn)
    if squid_pipeline_arn:
        pipelines_to_start.append(squid_pipeline_arn)
    if base_pipeline_arn:
        pipelines_to_start.append(base_pipeline_arn)

    results = {}
    all_successful = True

    if event['RequestType'] == 'Create' or event['RequestType'] == 'Update':
        for pipeline_arn in pipelines_to_start:
            try:
                print(f"Starting image pipeline execution for: {pipeline_arn}")
                response = imagebuilder.start_image_pipeline_execution(
                    imagePipelineArn=pipeline_arn
                )
                print(f"Successfully started pipeline {pipeline_arn}: {response}")
                results[pipeline_arn] = "Started successfully"
            except Exception as e:
                print(f"Error starting pipeline {pipeline_arn}: {e}")
                results[pipeline_arn] = f"Failed to start: {str(e)}"
                all_successful = False
        
        if all_successful:
            send(event, context, SUCCESS, {"message": "All specified image pipelines started.", "results": results})
        else:
            send(event, context, FAILED, {"message": "One or more image pipelines failed to start.", "results": results})

    elif event['RequestType'] == 'Delete':
        # No action needed on delete for starting pipelines
        print("Delete event received. No action taken to start pipelines.")
        send(event, context, SUCCESS, {"message": "Delete event: No action taken."})
    else:
        print(f"Unhandled event type: {event['RequestType']}")
        send(event, context, FAILED, {"message": f"Unhandled event type: {event['RequestType']}"})

    return {"status": "Lambda execution finished", "results": results}
