import * as cdk from "aws-cdk-lib";
import * as s3 from "aws-cdk-lib/aws-s3";
import { Duration, RemovalPolicy, SecretValue } from "aws-cdk-lib";
import {
  ISecurityGroup,
  InstanceType,
  Port,
  SecurityGroup,
  Vpc,
  SubnetType,
} from "aws-cdk-lib/aws-ec2";
import {
  AuroraPostgresEngineVersion,
  ClusterInstance,
  Credentials,
  DatabaseCluster,
  DatabaseClusterEngine,
} from "aws-cdk-lib/aws-rds";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import { Construct } from "constructs";
import { RDSConfig } from "./config";
import { Bucket } from "aws-cdk-lib/aws-s3";
import { PolicyStatement, Role, ServicePrincipal } from "aws-cdk-lib/aws-iam";
import { Function, Code, Runtime } from "aws-cdk-lib/aws-lambda";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";
import * as triggers from "aws-cdk-lib/triggers";
import { readFileSync } from "fs";

export class DataBaseConstruct {
  sg: SecurityGroup;
  db_cluster: DatabaseCluster;
  password: string;
  bucket: cdk.aws_s3.Bucket;
  lambdaRole: Role;

  constructor(scope: Construct, rds_config: RDSConfig, vpc: Vpc) {
    const engine = DatabaseClusterEngine.auroraPostgres({
      version: AuroraPostgresEngineVersion.VER_13_7,
    });

    this.password = rds_config.password;

    const secret = new Secret(scope, rds_config.secret_name, {
      secretName: rds_config.secret_name,
      description: "Database master user credentials",
      secretObjectValue: {
        dbname: SecretValue.unsafePlainText(rds_config.db_name),
        username: SecretValue.unsafePlainText(rds_config.db_user),
        password: SecretValue.unsafePlainText(this.password),
      },
    });

    const lambdaSecurityGroup = new SecurityGroup(
      scope,
      "LambdaSecurityGroup",
      {
        vpc,
        allowAllOutbound: true,
      }
    );

    this.sg = new SecurityGroup(scope, "Hyperswitch-db-SG", {
      securityGroupName: "Hyperswitch-db-SG",
      vpc: vpc,
    });

    this.sg.addIngressRule(
      lambdaSecurityGroup,
      Port.tcp(rds_config.port)
    );

    this.bucket = new Bucket(scope, "SchemaBucket", {
      removalPolicy: RemovalPolicy.DESTROY,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: false,
      }),
      publicReadAccess: true,
      autoDeleteObjects: true,
      bucketName:
        "hyperswitch-schema-" +
        cdk.Aws.ACCOUNT_ID +
        "-" +
        process.env.CDK_DEFAULT_REGION,
    });

    this.lambdaRole = new Role(scope, "schemaUploadLambdaRole", {
      assumedBy: new ServicePrincipal("lambda.amazonaws.com"),
    });

    this.lambdaRole.addToPolicy(
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
          "s3:PutObject",
        ],
        resources: ["*", this.bucket.bucketArn + "/*"],
      })
    );

    this.db_cluster = new DatabaseCluster(scope, "hyperswitch-db-cluster", {
      writer: ClusterInstance.provisioned("Writer Instance", {
        instanceType: InstanceType.of(
          rds_config.writer_instance_class,
          rds_config.writer_instance_size
        ),
        publiclyAccessible: true,
      }),
      // Should reader instance configs be Optional?
      readers: [
        ClusterInstance.provisioned("Reader Instance", {
          instanceType: InstanceType.of(
            rds_config.reader_instance_class,
            rds_config.reader_instance_size
          ),
          publiclyAccessible: true,
        }),
      ],
      vpc,
      vpcSubnets: { subnetType: SubnetType.PUBLIC },
      engine,
      port: rds_config.port,
      securityGroups: [this.sg],
      defaultDatabaseName: rds_config.db_name,
      credentials: Credentials.fromSecret(secret),
      removalPolicy: RemovalPolicy.DESTROY,
    });

    // Add ingress rule to allow traffic from any IP address
    this.db_cluster.connections.allowFromAnyIpv4(Port.tcp(rds_config.port));

    const uploadSchemaAndMigrationCode = readFileSync(
      "./dependencies/schema_upload.py",
      "utf8"
    ).replaceAll("{{BUCKET_NAME}}", this.bucket.bucketName);

    const uploadSchemaFunction = new Function(scope, "uploadSchemaFunction", {
      runtime: Runtime.PYTHON_3_9,
      handler: "index.lambda_handler",
      code: Code.fromInline(uploadSchemaAndMigrationCode),
      timeout: Duration.minutes(15),
      role: this.lambdaRole,
    });

    const uploadSchemaTriggerCustomResource = new cdk.CustomResource(
      scope,
      "uploadSchemaTriggerCustomResource",
      {
        serviceToken: uploadSchemaFunction.functionArn,
      }
    );

    const initializeDBFunction = new Function(scope, "InitializeDBFunction", {
      runtime: Runtime.PYTHON_3_9,
      handler: "index.db_handler",
      code: Code.fromBucket(this.bucket, "migration_runner.zip"),
      environment: {
        DB_SECRET_ARN: secret.secretArn,
        SCHEMA_BUCKET: this.bucket.bucketName,
        SCHEMA_FILE_KEY: "schema.sql",
      },
      vpc: vpc,
      securityGroups: [lambdaSecurityGroup],
      timeout: Duration.minutes(15),
      role: this.lambdaRole,
    });

    new triggers.Trigger(scope, "InitializeDBTrigger", {
      handler: initializeDBFunction,
      timeout: Duration.minutes(15),
      invocationType: triggers.InvocationType.REQUEST_RESPONSE,
    }).executeAfter(this.db_cluster);

    initializeDBFunction.node.addDependency(uploadSchemaTriggerCustomResource);
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
