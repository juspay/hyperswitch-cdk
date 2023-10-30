import { RemovalPolicy, SecretValue, StackProps } from "aws-cdk-lib";
import { Duration } from '@aws-cdk/core';
import {
  ISecurityGroup,
  InstanceClass,
  InstanceSize,
  InstanceType,
  Port,
  SecurityGroup,
  Vpc,
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
import { SubnetNames } from "./networking";
import { RDSConfig } from "./config";
import { Bucket } from "aws-cdk-lib/aws-s3";
import { Asset } from "aws-cdk-lib/aws-s3-assets";
import { PolicyStatement, Role, ServicePrincipal } from "aws-cdk-lib/aws-iam";
import { Function, Code, Runtime } from "aws-cdk-lib/aws-lambda";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";
import * as triggers from 'aws-cdk-lib/triggers';

export class DataBaseConstruct {
  sg: SecurityGroup;
  db_cluster: DatabaseCluster;
  password: string;

  constructor(
    scope: Construct,
    rds_config: RDSConfig,
    vpc: Vpc
  ) {
    const engine = DatabaseClusterEngine.auroraPostgres({
      version: AuroraPostgresEngineVersion.VER_13_7,
    });

    const db_name = "hyperswitch";

    const db_security_group = new SecurityGroup(scope, "Hyperswitch-db-SG", {
      securityGroupName: "Hyperswitch-db-SG",
      vpc: vpc,
    });

    this.sg = db_security_group;


    const secretName = 'hypers-db-master-user-secret';

    // Create the secret if it doesn't exist
    let secret= new Secret(scope, "hypers-db-master-user-secret", {
            secretName: secretName,
            description: "Database master user credentials",
            secretObjectValue: {
              dbname: SecretValue.unsafePlainText(db_name),
              username: SecretValue.unsafePlainText("db_user"),
              password: SecretValue.unsafePlainText(rds_config.password)
            }
          });

    this.password = rds_config.password;
    const db_cluster = new DatabaseCluster(
      scope,
      "hyperswitch-db-cluster",
      {
        writer: ClusterInstance.provisioned("Writer Instance", {
          instanceType: InstanceType.of(
            rds_config.writer_instance_class,
            rds_config.writer_instance_size
          ),
          publiclyAccessible: true,
        }),
        // readers: [
        //   ClusterInstance.provisioned("Reader Instance", {
        //     instanceType: InstanceType.of(
        //       rds_config.reader_instance_class,
        //       rds_config.reader_instance_size
        //     ),
        //   }),
        // ],
        vpc,
        vpcSubnets: { subnetGroupName: SubnetNames.PublicSubnet },
        engine,
        port: rds_config.port,
        securityGroups: [db_security_group],
        defaultDatabaseName: db_name,
        credentials: Credentials.fromSecret(secret),
        removalPolicy: RemovalPolicy.DESTROY,
      }
    );

    // Add ingress rule to allow traffic from any IP address
    db_cluster.connections.allowFromAnyIpv4(Port.tcp(rds_config.port));

    this.db_cluster = db_cluster;

    let schemaBucket = new Bucket(scope, 'SchemaBucket', {
      removalPolicy: RemovalPolicy.DESTROY,
      bucketName: 'hyperswitch-schema-bucket-'+process.env.CDK_DEFAULT_REGION,
    });


    const bucketDeployment = new BucketDeployment(scope, 'DeploySchemaToBucket', {
      sources: [Source.asset('./dependencies/schema')],
      destinationBucket: schemaBucket,
    });

    const lambdaRole = new Role(scope, 'RDSLambdaRole', {
      assumedBy: new ServicePrincipal('lambda.amazonaws.com'),
    });

    schemaBucket.grantRead(lambdaRole, 'dependencies/schema.sql');

    lambdaRole.addToPolicy(
      new PolicyStatement({
          actions: ['secretsmanager:GetSecretValue', 'logs:CreateLogGroup', 'logs:CreateLogStream', 'logs:PutLogEvents', 's3:GetObject'],
          resources: ['*', schemaBucket.bucketArn + '/*'],
      })
    );

    const lambdaSecurityGroup = new SecurityGroup(scope, 'LambdaSecurityGroup', {
      vpc,
      allowAllOutbound: true,
    });

  db_security_group.addIngressRule(lambdaSecurityGroup, Port.tcp(rds_config.port));

    const initializeDBFunction = new Function(scope, 'InitializeDBFunction', {
      runtime: Runtime.PYTHON_3_9,
      handler: 'index.db_handler',
      // code: Code.fromAsset('./dependencies/lambda_package/rds_lambda.py'),
      code: Code.fromAsset('./dependencies/migration_runner/migration_runner.zip'),
      environment: {
          DB_SECRET_ARN: secret.secretArn,
          SCHEMA_BUCKET: schemaBucket.bucketName,
          SCHEMA_FILE_KEY: 'schema.sql',
      },
      timeout: Duration.minutes(15),
      role: lambdaRole
    });

    new triggers.Trigger(scope, 'InitializeDBTrigger', {
      handler: initializeDBFunction,
      timeout: Duration.minutes(15),
      invocationType: triggers.InvocationType.EVENT,
      executeAfter: [db_cluster]
    });
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