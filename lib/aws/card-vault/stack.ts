import * as cdk from "aws-cdk-lib";
import { IVpc, SecurityGroup, Vpc } from "aws-cdk-lib/aws-ec2";
import { PolicyStatement, Role, ServicePrincipal } from "aws-cdk-lib/aws-iam";
import { Function, Code, Runtime } from "aws-cdk-lib/aws-lambda";

import { Bucket } from "aws-cdk-lib/aws-s3";
import * as s3 from "aws-cdk-lib/aws-s3";

import { Construct } from "constructs";
import { readFileSync } from "fs";
import { LockerSetup } from "./components";

export type StandaloneLockerConfig = {
  vpc_id: string;
  name: string;
  master_key: string;
  db_user: string;
  db_pass: string;
};

export class JusVault extends cdk.Stack {
  schemaBucket: s3.Bucket;
  vpc: IVpc;
  locker: LockerSetup;

  constructor(scope: Construct, config: StandaloneLockerConfig) {
    super(scope, config.name, {
      env: {
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: process.env.CDK_DEFAULT_REGION,
      },
      stackName: config.name,
    });

    this.vpc = Vpc.fromLookup(this, "TheVpc", {
      vpcId: config.vpc_id,
    });

    const schemaBucket = new Bucket(this, "SchemaBucket", {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: false,
      }),
      publicReadAccess: true,
      autoDeleteObjects: true,
      bucketName:
        "locker-schema-" +
        cdk.Aws.ACCOUNT_ID +
        "-" +
        process.env.CDK_DEFAULT_REGION,
    });

    this.schemaBucket = schemaBucket;

    let migrationCode = readFileSync("lib/aws/card-vault/migration.py", "utf8")
      .replaceAll("{{ACCOUNT}}", process.env.CDK_DEFAULT_ACCOUNT!)
      .replaceAll("{{REGION}}", process.env.CDK_DEFAULT_REGION!);

    const lambdaRole = new Role(this, "SchemaUploadLambdaRole", {
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
          "s3:PutObject",
        ],
        resources: ["*", schemaBucket.bucketArn + "/*"],
      }),
    );

    const lambdaSecurityGroup = new SecurityGroup(this, "LambdaSecurityGroup", {
      vpc: this.vpc,
      allowAllOutbound: true,
    });

    const initializeUploadFunction = new Function(
      this,
      "initializeUploadFunction",
      {
        runtime: Runtime.PYTHON_3_9,
        handler: "index.lambda_handler",
        code: Code.fromInline(migrationCode),
        timeout: cdk.Duration.minutes(15),
        role: lambdaRole,
        // securityGroups: [lambdaSecurityGroup],
      },
    );

    const initializeDbTriggerCustomResource = new cdk.CustomResource(
      this,
      "InitializeDbTriggerCustomResource",
      {
        serviceToken: initializeUploadFunction.functionArn,
      },
    );

    let locker = new LockerSetup(
      this,
      this.vpc,
      {
        db_pass: config.db_pass,
        db_user: config.db_user,
        master_key: config.master_key,
      },
      this.schemaBucket,
    );

    this.locker = locker;
  }
}
