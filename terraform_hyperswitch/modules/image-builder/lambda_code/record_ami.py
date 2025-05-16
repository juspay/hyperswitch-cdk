import json
import boto3
import os

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    
    ssm_parameter_name = os.environ.get('IMAGE_SSM_NAME')
    if not ssm_parameter_name:
        print("Error: IMAGE_SSM_NAME environment variable not set.")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'IMAGE_SSM_NAME not set'})
        }

    try:
        # Assuming the event is from SNS, triggered by Image Builder
        if 'Records' in event:
            for record in event['Records']:
                if 'Sns' in record:
                    sns_message_str = record['Sns']['Message']
                    print(f"SNS Message String: {sns_message_str}")
                    
                    # The SNS message from Image Builder is a JSON string.
                    try:
                        sns_message = json.loads(sns_message_str)
                    except json.JSONDecodeError as e:
                        print(f"Error decoding SNS message JSON: {e}")
                        print(f"Problematic SNS message string: {sns_message_str}")
                        continue # Skip this record

                    if sns_message.get('state', {}).get('status') == 'AVAILABLE':
                        ami_id = None
                        # Find the AMI ID in the outputResources
                        if 'outputResources' in sns_message and 'amis' in sns_message['outputResources']:
                            for ami_resource in sns_message['outputResources']['amis']:
                                if 'image' in ami_resource: # image is the AMI ID
                                    ami_id = ami_resource['image']
                                    # Ensure it's a valid AMI ID format
                                    if not ami_id.startswith("ami-"):
                                        print(f"Extracted image ID '{ami_id}' does not look like an AMI ID.")
                                        ami_id = None # Reset if not valid
                                    break 
                        
                        if ami_id:
                            print(f"New AMI ID available: {ami_id} for parameter {ssm_parameter_name}")
                            ssm = boto3.client('ssm')
                            ssm.put_parameter(
                                Name=ssm_parameter_name,
                                Value=ami_id,
                                Type='String', # Or StringList, SecureString as needed
                                Overwrite=True # Update if exists
                            )
                            print(f"Successfully updated SSM parameter {ssm_parameter_name} with AMI ID {ami_id}")
                        else:
                            print("AMI ID not found or not valid in the SNS message.")
                    else:
                        print(f"Image build status is not 'AVAILABLE': {sns_message.get('state', {}).get('status')}")
                else:
                    print("Record does not contain SNS data.")
        else:
            print("Event does not contain 'Records'. This might not be an SNS event.")

    except Exception as e:
        print(f"Error processing event: {e}")
        # Depending on the trigger, might need to raise error or handle gracefully
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete.')
    }
