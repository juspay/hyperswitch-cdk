import json
import boto3
import os

SUCCESS = "SUCCESS"
FAILED = "FAILED"

def send(event, context, response_status, response_data, physical_resource_id=None, no_echo=False, reason=None):
    response_url = event.get('ResponseURL')
    if not response_url:
        print("No ResponseURL found in event. Skipping CFN response for non-custom resource.")
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

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    codebuild = boto3.client('codebuild')
    project_name = os.environ.get('PROJECT_NAME')

    if not project_name:
        error_msg = "PROJECT_NAME environment variable not set."
        print(error_msg)
        if event.get('RequestType') != 'Delete': # Only send if not a delete event that failed due to missing env var
            send(event, context, FAILED, {"message": error_msg})
        return {"status": "FAILED", "error": error_msg}

    if event['RequestType'] == 'Create' or event['RequestType'] == 'Update':
        try:
            print(f"Starting CodeBuild project: {project_name}")
            response = codebuild.start_build(projectName=project_name)
            build_id = response['build']['id']
            print(f"Successfully started CodeBuild project {project_name}, Build ID: {build_id}")
            send(event, context, SUCCESS, {"message": f"CodeBuild project {project_name} started.", "build_id": build_id})
        except Exception as e:
            error_msg = f"Error starting CodeBuild project {project_name}: {e}"
            print(error_msg)
            send(event, context, FAILED, {"message": error_msg})
            return {"status": "FAILED", "error": str(e)}

    elif event['RequestType'] == 'Delete':
        print(f"Delete event received for CodeBuild trigger of project {project_name}. No explicit delete action taken for the build itself.")
        send(event, context, SUCCESS, {"message": "Delete event: No action taken for CodeBuild project."})
    else:
        error_msg = f"Unhandled event type: {event['RequestType']}"
        print(error_msg)
        send(event, context, FAILED, {"message": error_msg})
        return {"status": "FAILED", "error": error_msg}
        
    return {"status": "Lambda execution finished."}
