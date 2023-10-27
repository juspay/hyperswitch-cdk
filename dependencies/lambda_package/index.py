import json
import os
import boto3
import psycopg2
import psycopg2.extensions
from botocore.exceptions import ClientError

def handler(event, context):
    secret_name = os.environ['DB_SECRET_ARN']
    client = boto3.client('secretsmanager')
    get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    secret = get_secret_value_response['SecretString']
    creds = json.loads(secret)

    s3_client = boto3.client('s3')
    s3_bucket_name = os.environ['SCHEMA_BUCKET']
    s3_object_key = os.environ['SCHEMA_FILE_KEY']

    s3_response = s3_client.get_object(Bucket=s3_bucket_name, Key=s3_object_key)
    schema_sql = s3_response['Body'].read().decode('utf-8')
    connection = psycopg2.connect(
        dbname=creds['dbname'],
        user=creds['username'],
        password=creds['password'],
        host=creds['host'],
        port=creds['port']
    )
    connection.autocommit = True
    cursor = connection.cursor()
    cursor.execute(schema_sql)
    cursor.close()
    connection.close()

    return {
        'statusCode': 200,
        'body': json.dumps('Database schema initialized successfully.')
    }