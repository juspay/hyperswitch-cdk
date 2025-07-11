import os
import json
import boto3


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


def lambda_handler(event, context):
    print("Received event:")
    print(json.dumps(event))

    try:
        worker()
        message = "ImageBuilder pipelines triggered successfully"
        print(message)
        return {
            "statusCode": 200,
            "body": json.dumps({"message": message})
        }
    except Exception as e:
        print("Error:", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
