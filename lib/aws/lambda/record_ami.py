from typing import Union
import json
import os
import logging
import boto3
logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger(__name__)


def lambda_handler(event, _):
    logger.info(event)

    message_body = event.get("Records")[0].get("Sns").get("Message")
    json_body = json.loads(message_body)
    ami = json_body["outputResources"]["amis"][0]["image"]
    ssm_key = os.environ["IMAGE_SSM_NAME"]
    logger.info(f"updating ssm {ssm_key}")
    ssm_client = boto3.client("ssm")
    try:
        result = ssm_client.put_parameter(
            Name=ssm_key,
            Value=ami,
            Type="String",
            DataType="text",
            Tier="Advanced",
            Overwrite=True,
        )
        logger.info(result)
    except Exception as e:
        logger.error(e)

    return create_response(200, {})


def create_response(code: int, body: Union[dict, str]):
    json_content = {
        "statusCode": code,
    }
    return json_content
