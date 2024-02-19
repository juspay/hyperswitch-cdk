import * as cdk from "aws-cdk-lib";
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Duration, RemovalPolicy, SecretValue } from "aws-cdk-lib";
import {
  ISecurityGroup,
  InstanceType,
  Port,
  SecurityGroup,
  Vpc,
  SubnetType,
  InstanceClass,
  InstanceSize
} from "aws-cdk-lib/aws-ec2";
import {
  AuroraPostgresEngineVersion,
  ClusterInstance,
  Credentials,
  DatabaseCluster,
  DatabaseClusterEngine,
  DatabaseInstance,
  DatabaseInstanceEngine,
  PostgresEngineVersion,
} from "aws-cdk-lib/aws-rds";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import { Construct } from "constructs";
import { RDSConfig } from "./config";
import { Bucket } from "aws-cdk-lib/aws-s3";
import { PolicyStatement, Role, ServicePrincipal } from "aws-cdk-lib/aws-iam";
import { Function, Code, Runtime } from "aws-cdk-lib/aws-lambda";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";
import * as triggers from "aws-cdk-lib/triggers";

export class DataBaseConstruct {
  sg: SecurityGroup;
  dbCluster?: DatabaseCluster;
  standaloneDb?: DatabaseInstance;
  password: string;
  bucket: cdk.aws_s3.Bucket;

  constructor(scope: Construct, rds_config: RDSConfig, vpc: Vpc, isStandalone: boolean) {
    const db_name = "hyperswitch";

    const db_security_group = new SecurityGroup(scope, "Hyperswitch-db-SG", {
      securityGroupName: "Hyperswitch-db-SG",
      vpc: vpc,
    });

    const secretName = "hypers-db-master-user-secret";

    let secret = new Secret(scope, "hypers-db-master-user-secret", {
      secretName: secretName,
      description: "Database master user credentials",
      secretObjectValue: {
        dbname: SecretValue.unsafePlainText(db_name),
        username: SecretValue.unsafePlainText(rds_config.db_user),
        password: SecretValue.unsafePlainText(rds_config.password),
      },
    });

    this.password = rds_config.password;
    this.sg = db_security_group;

    if (isStandalone) {

      this.standaloneDb = new DatabaseInstance(scope, "hyperswitch-db", {
        engine: DatabaseInstanceEngine.postgres({
          version: PostgresEngineVersion.VER_14,
        }),
        instanceType: InstanceType.of(
          InstanceClass.T3,
          InstanceSize.MICRO
        ),
        vpc,
        vpcSubnets: { subnetType: SubnetType.PUBLIC },
        securityGroups: [this.sg],
        databaseName: rds_config.db_name,
        credentials: Credentials.fromSecret(secret),
        port: rds_config.port,
        removalPolicy: RemovalPolicy.DESTROY,
      });

      this.sg.addIngressRule(ec2.Peer.ipv4("0.0.0.0/0"), ec2.Port.tcp(5432));

      const schemaBucket = new Bucket(scope, "SchemaBucket", {
        removalPolicy: RemovalPolicy.DESTROY,
        blockPublicAccess: new s3.BlockPublicAccess({
          blockPublicAcls: false,
        }),
        publicReadAccess: true,
        autoDeleteObjects: true,
        bucketName:
          "hyperswitch-schema-" +
          cdk.Aws.ACCOUNT_ID + "-" +
          process.env.CDK_DEFAULT_REGION
      });

      this.bucket = schemaBucket;

      const uploadSchemaAndMigrationCode = `import boto3
import urllib3
import json

SUCCESS = "SUCCESS"
FAILED = "FAILED"

http = urllib3.PoolManager()


def send(event, context, responseStatus, responseData, physicalResourceId=None, noEcho=False, reason=None):
    responseUrl = event['ResponseURL']

    responseBody = {
        'Status' : responseStatus,
        'Reason' : reason or "See the details in CloudWatch Log Stream: {}".format(context.log_stream_name),
        'PhysicalResourceId' : physicalResourceId or context.log_stream_name,
        'StackId' : event['StackId'],
        'RequestId' : event['RequestId'],
        'LogicalResourceId' : event['LogicalResourceId'],
        'NoEcho' : noEcho,
        'Data' : responseData
    }

    json_responseBody = json.dumps(responseBody)

    print("Response body:")
    print(json_responseBody)

    headers = {
        'content-type' : '',
        'content-length' : str(len(json_responseBody))
    }

    try:
        response = http.request('PUT', responseUrl, headers=headers, body=json_responseBody)
        print("Status code:", response.status)

    except Exception as e:

        print("send(..) failed executing http.request(..):", e)

def upload_file_from_url(url, bucket, key):
    s3=boto3.client('s3')
    http=urllib3.PoolManager()
    s3.upload_fileobj(http.request('GET', url,preload_content=False), bucket, key)
    s3.upload_fileobj

def lambda_handler(event, context):
    try:
        # Call the upload_file_from_url function to upload two files to S3
        if event['RequestType'] == 'Create':
          upload_file_from_url("https://hyperswitch-bucket.s3.amazonaws.com/migration_runner.zip", "hyperswitch-schema-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}", "migration_runner.zip")
          upload_file_from_url("https://hyperswitch-bucket.s3.amazonaws.com/schema.sql", "hyperswitch-schema-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}", "schema.sql")
          upload_file_from_url("https://hyperswitch-bucket.s3.amazonaws.com/locker-schema.sql", "hyperswitch-schema-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}", "locker-schema.sql")
          send(event, context, SUCCESS, { "message" : "Files uploaded successfully"})
        else:
          send(event, context, SUCCESS, { "message" : "No action required"})
    except Exception as e:  # Use 'Exception as e' to properly catch and define the exception variable
        # Handle exceptions and return an error message
        send(event, context, FAILED, {"message": str(e)})
        return str(e)
    # Return a success message
    return '{ "status": 200, "message": "success" }'
      `

      const lambdaRole = new Role(scope, "SchemaUploadLambdaRole", {
        assumedBy: new ServicePrincipal("lambda.amazonaws.com"),
      });

      lambdaRole.addToPolicy(
        new PolicyStatement({
          actions: [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:AttachNetworkInterface",
            "ec2:DetachNetworkInterface",
            "secretsmanager:GetSecretValue",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "s3:GetObject",
            "s3:PutObject"
          ],
          resources: ["*", schemaBucket.bucketArn + "/*"],
        })
      );

      const lambdaSecurityGroup = new SecurityGroup(
        scope,
        "LambdaSecurityGroup",
        {
          vpc,
          allowAllOutbound: true,
        }
      );

      db_security_group.addIngressRule(
        lambdaSecurityGroup,
        Port.tcp(rds_config.port)
      );

      const initializeUploadFunction = new Function(scope, "initializeUploadFunction", {
        runtime: Runtime.PYTHON_3_9,
        handler: "index.lambda_handler",
        code: Code.fromInline(uploadSchemaAndMigrationCode),
        timeout: Duration.minutes(15),
        role: lambdaRole,
      });


      const initializeDbTriggerCustomResource = new cdk.CustomResource(scope, 'InitializeDbTriggerCustomResource', {
        serviceToken: initializeUploadFunction.functionArn,
      });

      const initializeDBFunction = new Function(scope, "InitializeDBFunction", {
        runtime: Runtime.PYTHON_3_9,
        handler: "index.db_handler",
        code: Code.fromBucket(schemaBucket, "migration_runner.zip"),
        environment: {
          DB_SECRET_ARN: secret.secretArn,
          SCHEMA_BUCKET: schemaBucket.bucketName,
          SCHEMA_FILE_KEY: "schema.sql",
        },
        vpc: vpc,
        securityGroups: [lambdaSecurityGroup],
        timeout: Duration.minutes(15),
        role: lambdaRole,
      });

      new triggers.Trigger(scope, "initializeUploadTrigger", {
        handler: initializeUploadFunction,
        timeout: Duration.minutes(15),
        invocationType: triggers.InvocationType.EVENT,
      }).executeBefore();

      new triggers.Trigger(scope, "InitializeDBTrigger", {
        handler: initializeDBFunction,
        timeout: Duration.minutes(15),
        invocationType: triggers.InvocationType.REQUEST_RESPONSE,
      }).executeAfter(this.standaloneDb);

      initializeDBFunction.node.addDependency(initializeDbTriggerCustomResource);
    }
    else {

      const engine = DatabaseClusterEngine.auroraPostgres({
        version: AuroraPostgresEngineVersion.VER_13_7,
      });

      const dbCluster = new DatabaseCluster(scope, "hyperswitch-db-cluster", {
        writer: ClusterInstance.provisioned("Writer Instance", {
          instanceType: InstanceType.of(
            rds_config.writer_instance_class,
            rds_config.writer_instance_size
          ),
          publiclyAccessible: isStandalone,
        }),
        readers: isStandalone ? [] :
          [
            ClusterInstance.provisioned("Reader Instance", {
              instanceType: InstanceType.of(
                rds_config.reader_instance_class,
                rds_config.reader_instance_size
              ),
            }),
          ],
        vpc,
        vpcSubnets: { subnetType: isStandalone ? SubnetType.PUBLIC : SubnetType.PRIVATE_WITH_EGRESS },
        engine,
        storageEncrypted: true,
        port: rds_config.port,
        securityGroups: [db_security_group],
        defaultDatabaseName: db_name,
        credentials: Credentials.fromSecret(secret),
        removalPolicy: RemovalPolicy.DESTROY,
      });

      this.dbCluster = dbCluster;
    }
    // For standalone deployment, create a bucket to store the schema and migration code
  }

  addClient(
    peer: ISecurityGroup,
    port: number,
    description?: string,
    remote_rule?: boolean
  ) {
    this.sg.addIngressRule(peer, Port.tcp(port), description, remote_rule);
    peer.addEgressRule(this.sg, Port.tcp(port), description, remote_rule);
  }
}