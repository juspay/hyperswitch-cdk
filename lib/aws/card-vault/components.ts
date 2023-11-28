import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import { readFileSync } from "fs";
import * as cdk from "aws-cdk-lib";

import { generateKeyPairSync } from "crypto";
import { SubnetNames } from "../networking";
import * as kms from "aws-cdk-lib/aws-kms";
import * as iam from "aws-cdk-lib/aws-iam";
import {
  AuroraPostgresEngineVersion,
  ClusterInstance,
  Credentials,
  DatabaseCluster,
  DatabaseClusterEngine,
  InstanceType,
} from "aws-cdk-lib/aws-rds";
import { SecurityGroup } from "aws-cdk-lib/aws-ec2";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import * as s3 from "aws-cdk-lib/aws-s3";
import { Code, Function, Runtime } from "aws-cdk-lib/aws-lambda";
import { LockerConfig } from "../config";
import { RetentionDays } from "aws-cdk-lib/aws-logs";

type LockerData = {
  master_key: string; // kms encrypted
  database: {
    user: string;
    password: string; // kms encrypted
    host: string;
  };
};

type RsaKeyPair = {
  private_key: string;
  public_key: string;
};

export class LockerEc2 {
  readonly instance: ec2.Instance;
  sg: ec2.SecurityGroup;
  readonly locker_pair: RsaKeyPair;
  readonly hyperswitch: RsaKeyPair;
  readonly kms_key: kms.Key;

  constructor(scope: Construct, vpc: ec2.IVpc, locker_data: LockerData) {
    const kms_key = new kms.Key(scope, "locker-kms-key", {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      pendingWindow: cdk.Duration.days(7),
      keyUsage: kms.KeyUsage.ENCRYPT_DECRYPT,
      keySpec: kms.KeySpec.SYMMETRIC_DEFAULT,
      alias: "alias/locker-kms-key",
      description: "KMS key for encrypting the objects in an S3 bucket",
      enableKeyRotation: false,
    });

    const envBucket = new s3.Bucket(scope, "LockerEnvBucket", {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: true,
      }),
      publicReadAccess: false,
      autoDeleteObjects: true,
      bucketName:
        "locker-env-store-" +
        cdk.Aws.ACCOUNT_ID +
        "-" +
        process.env.CDK_DEFAULT_REGION,
    });

    const kms_policy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: ["kms:*"],
          resources: [kms_key.keyArn],
        }),
        new iam.PolicyStatement({
          actions: ["secretsmanager:*"],
          resources: ["*"],
        }),
        new iam.PolicyStatement({
          actions: ["s3:PutObject"],
          resources: [`${envBucket.bucketArn}/*`],
        }),
      ],
    });

    const lambda_role = new iam.Role(scope, "locker-lambda-role", {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
      inlinePolicies: {
        "use-kms-sm-s3": kms_policy,
      },
    });

    const { privateKey: locker_private_key, publicKey: locker_public_key } =
      generateKeyPairSync("rsa", {
        modulusLength: 2048,
      });

    this.locker_pair = {
      public_key: locker_public_key
        .export({ type: "spki", format: "pem" })
        .toString(),
      private_key: locker_private_key
        .export({ type: "pkcs8", format: "pem" })
        .toString(),
    };

    const { privateKey: tenant_private_key, publicKey: tenant_public_key } =
      generateKeyPairSync("rsa", {
        modulusLength: 2048,
      });

    this.hyperswitch = {
      public_key: tenant_public_key
        .export({ type: "spki", format: "pem" })
        .toString(),
      private_key: tenant_private_key
        .export({ type: "pkcs8", format: "pem" })
        .toString(),
    };

    let secret = new Secret(scope, "locker-kms-userdata-secret", {
      secretName: "LockerKmsDataSecret",
      description: "Database master user credentials",
      secretObjectValue: {
        db_username: cdk.SecretValue.unsafePlainText(locker_data.database.user),
        db_password: cdk.SecretValue.unsafePlainText(
          locker_data.database.password,
        ),
        db_host: cdk.SecretValue.unsafePlainText(locker_data.database.host),
        master_key: cdk.SecretValue.unsafePlainText(locker_data.master_key),
        private_key: cdk.SecretValue.unsafePlainText(
          this.locker_pair.private_key,
        ),
        public_key: cdk.SecretValue.unsafePlainText(
          this.hyperswitch.public_key,
        ),
        kms_id: cdk.SecretValue.unsafePlainText(kms_key.keyId),
        region: cdk.SecretValue.unsafePlainText(kms_key.stack.region),
      },
    });

    const encryption_code = readFileSync(
      "lib/aws/card-vault/encryption.py",
    ).toString();

    let env_file = "envfile";

    const kms_encrypt_function = new Function(scope, "kms-encrypt", {
      functionName: "KmsEncryptionLambda",
      runtime: Runtime.PYTHON_3_9,
      handler: "index.lambda_handler",
      code: Code.fromInline(encryption_code),
      timeout: cdk.Duration.minutes(15),
      role: lambda_role,
      environment: {
        SECRET_MANAGER_ARN: secret.secretArn,
        ENV_BUCKET_NAME: envBucket.bucketName,
        ENV_FILE: env_file,
      },
      logRetention: RetentionDays.INFINITE,
    });

    const triggerKMSEncryption = new cdk.CustomResource(scope, "KmsEncryptionCR", {
      serviceToken: kms_encrypt_function.functionArn,
    });

    const userDataResponse = triggerKMSEncryption.getAtt("message").toString();

    const locker_role = new iam.Role(scope, "locker-role", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
      inlinePolicies: {
        "use-kms-sm-s3": kms_policy,
      },
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonS3ReadOnlyAccess"),
      ],
    });

    const sg = new ec2.SecurityGroup(scope, "Locker-SG", {
      securityGroupName: "Locker-SG",
      vpc: vpc,
    });

    this.sg = sg;
    let keypair_id = "locker-ec2-keypair";
    const aws_key_pair = new ec2.CfnKeyPair(scope, keypair_id, {
      keyName: "Locker-ec2-keypair",
    });

    new cdk.CfnOutput(scope, "GetLockerSSHKey", {
      value: `aws ssm get-parameter --name /ec2/keypair/$(aws ec2 describe-key-pairs --filters Name=key-name,Values=${aws_key_pair.keyName} --query "KeyPairs[*].KeyPairId" --output text) --with-decryption --query Parameter.Value --output text > new-key-pair.pem`,
    });

    let customData = readFileSync("lib/aws/card-vault/user-data.sh", "utf8")
      .replaceAll("{{BUCKET_NAME}}", envBucket.bucketName)
      .replaceAll("{{ENV_FILE}}", env_file);

    this.instance = new ec2.Instance(scope, "locker-ec2", {
      instanceType: ec2.InstanceType.of(
        ec2.InstanceClass.T3,
        ec2.InstanceSize.MEDIUM,
      ),
      machineImage: new ec2.AmazonLinuxImage(),
      vpc,
      vpcSubnets: {
        // subnetGroupName: SubnetNames.IsolatedSubnet,
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      },
      securityGroup: sg,
      keyName: aws_key_pair.keyName,
      userData: ec2.UserData.custom(customData),
      role: locker_role,
    });

    envBucket.grantRead(this.instance);

    new cdk.CfnOutput(scope, "Locker-ec2-IP", {
      value: `${this.instance.instancePrivateIp}`,
      description: "Locker Private IP",
    });
  }

  addClient(sg: ec2.ISecurityGroup, port: ec2.Port) {
    this.sg.addIngressRule(sg, port);
    sg.addEgressRule(this.sg, port);
  }

  addServer(sg: ec2.ISecurityGroup, port: ec2.Port) {
    this.sg.addEgressRule(sg, port);
    sg.addIngressRule(this.sg, port);
  }
}

export class LockerSetup {
  locker_ec2: LockerEc2;
  db_cluster: DatabaseCluster;
  db_sg: SecurityGroup;
  db_bucket: s3.Bucket;

  constructor(
    scope: Construct,
    vpc: ec2.IVpc,
    config: LockerConfig,
    rdsSchemaBucket: s3.Bucket,
  ) {
    // Creating Database for LockerData
    const engine = DatabaseClusterEngine.auroraPostgres({
      version: AuroraPostgresEngineVersion.VER_13_7,
    });

    const db_name = "locker";

    const db_security_group = new SecurityGroup(scope, "Locker-db-SG", {
      securityGroupName: "Locker-db-SG",
      vpc: vpc,
    });

    this.db_sg = db_security_group;

    const secretName = "LockerDbMasterUserSecret";

    // Create the secret if it doesn't exist
    let secret = new Secret(scope, "locker-db-master-user-secret", {
      secretName: secretName,
      description: "Database master user credentials",
      secretObjectValue: {
        dbname: cdk.SecretValue.unsafePlainText(db_name),
        username: cdk.SecretValue.unsafePlainText(config.db_user),
        password: cdk.SecretValue.unsafePlainText(config.db_pass),
      },
    });

    let schemaBucket = rdsSchemaBucket;

    this.db_bucket = schemaBucket;

    let migrationCode = readFileSync("lib/aws/card-vault/migration.py", "utf8")
      .replaceAll("{{ACCOUNT}}", process.env.CDK_DEFAULT_ACCOUNT!)
      .replaceAll("{{REGION}}", process.env.CDK_DEFAULT_REGION!);

    const lambdaRole = new iam.Role(scope, "SchemaUploadLambdaRole2", {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
    });

    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
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

    const lambdaSecurityGroup = new SecurityGroup(
      scope,
      "LambdaSecurityGroup2",
      {
        vpc,
        allowAllOutbound: true,
      },
    );

    db_security_group.addIngressRule(lambdaSecurityGroup, ec2.Port.tcp(5432));

    const db_cluster = new DatabaseCluster(scope, "locker-db-cluster", {
      writer: ClusterInstance.provisioned("Writer Instance", {
        instanceType: ec2.InstanceType.of(
          ec2.InstanceClass.T4G,
          ec2.InstanceSize.MEDIUM,
        ),
      }),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      engine,
      port: 5432,
      securityGroups: [db_security_group],
      defaultDatabaseName: db_name,
      credentials: Credentials.fromSecret(secret),
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Add ingress rule to allow traffic from any IP address
    db_cluster.connections.allowFromAnyIpv4(ec2.Port.tcp(5432));

    this.db_cluster = db_cluster;

    const initializeDBFunction = new Function(
      scope,
      "InitializeLockerDBFunction",
      {
        runtime: Runtime.PYTHON_3_9,
        handler: "index.db_handler",
        code: Code.fromBucket(schemaBucket, "migration_runner.zip"),
        environment: {
          DB_SECRET_ARN: secret.secretArn,
          SCHEMA_BUCKET: schemaBucket.bucketName,
          SCHEMA_FILE_KEY: "locker-schema.sql",
        },
        vpc: vpc,
        securityGroups: [lambdaSecurityGroup],
        timeout: cdk.Duration.minutes(15),
        role: lambdaRole,
      },
    );

    new cdk.triggers.Trigger(scope, "InitializeLockerDBTrigger", {
      handler: initializeDBFunction,
      timeout: cdk.Duration.minutes(15),
      invocationType: cdk.triggers.InvocationType.REQUEST_RESPONSE,
    }).executeAfter(db_cluster);

    this.locker_ec2 = new LockerEc2(scope, vpc, {
      master_key: config.master_key,
      database: {
        user: config.db_user,
        password: config.db_pass,
        host: db_cluster.clusterEndpoint.hostname,
      },
    });

    this.locker_ec2.addServer(this.db_sg, ec2.Port.tcp(5432));
  }
}
