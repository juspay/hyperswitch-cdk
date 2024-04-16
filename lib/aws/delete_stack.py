import os
import json
import boto3
import urllib3
import base64
from dataclasses import dataclass

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
    try:
        if event['RequestType'] == 'Delete':

            # Try to delete the loadbalancer created also
            loadbalancers = ["hyperswitch", "hyperswitch-control-center", "hyperswitch-logs", "hyperswitch-sdk-demo", "hyperswitch-web"]
            elbv2 = boto3.client('elbv2')
            reponse = elbv2.describe_load_balancers(Names=loadbalancers)
            for lb in reponse["LoadBalancers"]:
                try:
                    elbv2.delete_load_balancer(LoadBalancerArn=lb["LoadBalancerArn"])
                except:
                    print("Loadbalancer {} doesn't exist.".format(lb["LoadBalancerArn"]))

            send(event, context, "SUCCESS", {"message": "No action required"})
        else:
            send(event, context, "SUCCESS", {"message": "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        send(event, context, "FAILED", {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
