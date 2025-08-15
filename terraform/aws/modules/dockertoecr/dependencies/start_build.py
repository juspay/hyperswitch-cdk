import boto3
import os
import json

def lambda_handler(event, context):
    print("Received event:", json.dumps(event, indent=2))

    try:
        codebuild = boto3.client('codebuild')
        response = codebuild.start_build(
            projectName=os.environ['PROJECT_NAME'],
        )

        result_data = {
            "message": "CodeBuild project started",
            "build_id": response['build']['id'],
            "build_arn": response['build']['arn']
        }

        print("CodeBuild started successfully:", result_data)

        return {
            'statusCode': 200,
            'body': json.dumps(result_data)
        }

    except Exception as e:
        error_message = str(e)
        print("Error occurred:", error_message)

        # Raise exception to mark Terraform resource as failed
        raise Exception(f"Lambda execution failed: {error_message}")
