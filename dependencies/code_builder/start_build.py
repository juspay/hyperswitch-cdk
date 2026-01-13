import boto3
import os
import json
import urllib3
import time

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

            # Start the CodeBuild project
            print(f"Starting CodeBuild project: {os.environ['PROJECT_NAME']}")
            response = codebuild.start_build(
                projectName=os.environ['PROJECT_NAME'],
            )

            build_id = response['build']['id']
            print(f"CodeBuild started with ID: {build_id}")

            # Wait for the build to complete
            print("Waiting for CodeBuild to complete (this may take 10-15 minutes for image mirroring)...")
            max_wait_time = 900  # 15 minutes max
            wait_interval = 30  # Check every 30 seconds
            elapsed_time = 0

            while elapsed_time < max_wait_time:
                # Check remaining Lambda execution time (max 15 min)
                remaining_time = context.get_remaining_time_in_millis() / 1000
                if remaining_time < 60:  # Less than 1 minute left
                    send(event, context, "FAILED", {
                        "message": f"Lambda timeout approaching. Build {build_id} still running. Please check CodeBuild console."
                    })
                    return '{ "status": 500, "message": "timeout" }'

                # Get build status
                build_status = codebuild.batch_get_builds(ids=[build_id])
                status = build_status['builds'][0]['buildStatus']

                print(f"Build status: {status} (elapsed: {elapsed_time}s)")

                if status == 'SUCCEEDED':
                    print("CodeBuild completed successfully!")
                    send(event, context, "SUCCESS", {
                        "message": f"CodeBuild project completed successfully. Build ID: {build_id}"
                    })
                    return '{ "status": 200, "message": "success" }'

                elif status in ['FAILED', 'FAULT', 'STOPPED', 'TIMED_OUT']:
                    error_msg = f"CodeBuild {status}. Build ID: {build_id}. Check CloudWatch logs."
                    print(error_msg)
                    send(event, context, "FAILED", {"message": error_msg})
                    return '{ "status": 500, "message": "build_failed" }'

                # Still in progress, wait and check again
                time.sleep(wait_interval)
                elapsed_time += wait_interval

            # Timeout reached
            send(event, context, "FAILED", {
                "message": f"CodeBuild did not complete within {max_wait_time}s. Build ID: {build_id}"
            })
            return '{ "status": 500, "message": "timeout" }'

        except Exception as e:
            error_msg = f"Error: {str(e)}"
            print(error_msg)
            send(event, context, "FAILED", {"message": error_msg})
            return '{ "status": 500, "message": "error" }'
    else:
        send(event, context, "SUCCESS", {"message": "No action required"})

    return '{ "status": 200, "message": "success" }'
