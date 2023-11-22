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

  constructor(scope: Construct, vpc: ec2.Vpc, locker_data: LockerData) {
    const kms_key = new kms.Key(scope, "locker-kms-key", {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      pendingWindow: cdk.Duration.days(7),
      keyUsage: kms.KeyUsage.ENCRYPT_DECRYPT,
      keySpec: kms.KeySpec.RSA_2048,
      alias: "alias/mykey",
      description: "KMS key for encrypting the objects in an S3 bucket",
      enableKeyRotation: false,
    });

    const kms_policy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: ["kms:*"],
          resources: [kms_key.keyArn],
        }),
      ],
    });

    const lambda_role = new iam.Role(scope, "locker-lambda-role", {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
      inlinePolicies: {
        "use-kms": kms_policy,
      },
    });

    let secret = new Secret(scope, "locker-kms-userdata-secret", {
      secretName: "locker kms data secret",
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
        kms_id: cdk.SecretValue.unsafePlainText(locker_data.kms.id),
        region: cdk.SecretValue.unsafePlainText(locker_data.kms.region),
      },
    });

    const encryption_code = readFileSync(
      "lib/aws/card-vault/encryption.py",
    ).toString();

    const kms_encrypt_function = new Function(scope, "kms-encrypt", {
      runtime: Runtime.PYTHON_3_9,
      handler: "index.lambda_handler",
      code: Code.fromInline(encryption_code),
      timeout: cdk.Duration.minutes(15),
      role: lambda_role,
      environment: {
        SECRET_MANAGER_ARN: secret.secretArn,
      },
    });

    // new cdk.triggers.Trigger(scope, "kms encryption trigger", {
    //   handler: kms_encrypt_function,
    //   timeout: cdk.Duration.minutes(15),
    //   invocationType: cdk.triggers.InvocationType.REQUEST_RESPONSE,
    // }).executeAfter(kms_key);
    const triggerStuff = new cdk.CustomResource(scope, "kms encryption cr", {
      serviceToken: kms_encrypt_function.functionArn,
    });
    const userDataResponse: { Data: { content: string } } & any = triggerStuff
      .getAtt("Response")
      .toJSON();

    const locker_role = new iam.Role(scope, "locker-role", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
      inlinePolicies: {
        "use-kms": kms_policy,
      },
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

    const { locker_private_key, locker_public_key } = generateKeyPairSync(
      "rsa",
      {
        modulusLength: 2048,
      },
    );

    this.locker_pair.public_key = locker_public_key
      .export({ type: "spki", format: "pem" })
      .toString();
    this.locker_pair.private_key = locker_private_key
      .export({ type: "pkcs8", format: "pem" })
      .toString();

    const { tenant_private_key, tenant_public_key } = generateKeyPairSync(
      "rsa",
      {
        modulusLength: 2048,
      },
    );

    this.hyperswitch.public_key = tenant_public_key
      .export({ type: "spki", format: "pem" })
      .toString();
    this.hyperswitch.private_key = tenant_private_key
      .export({ type: "pkcs8", format: "pem" })
      .toString();

    let customData = readFileSync("lib/aws/card-vault/user-data.sh", "utf8")
      .replaceAll("{{db_user}}", locker_data.database.user)
      .replaceAll("{{kms_enc_db_pass}}", locker_data.database.password)
      .replaceAll("{{db_host}}", locker_data.database.host)
      .replaceAll("{{kms_enc_master_key}}", locker_data.master_key)
      .replaceAll("{{kms_enc_lpriv_key}}", this.locker_pair.private_key)
      .replaceAll("{{kms_enc_tpub_key}}", this.hyperswitch.public_key)
      .replaceAll("{{kms_id}}", locker_data.kms.id)
      .replaceAll("{{kms_region}}", locker_data.kms.region);

    this.instance = new ec2.Instance(scope, "locker-ec2", {
      instanceType: ec2.InstanceType.of(
        ec2.InstanceClass.T3,
        ec2.InstanceSize.MEDIUM,
      ),
      machineImage: new ec2.AmazonLinuxImage(),
      vpc,
      vpcSubnets: {
        subnetGroupName: SubnetNames.IsolatedSubnet,
      },
      securityGroup: sg,
      keyName: aws_key_pair.keyName,
      userData: ec2.UserData.custom(customData),
      role: locker_role,
    });

    new cdk.CfnOutput(scope, "Locker-ec2-IP", {
      value: `http://${this.instance.instancePrivateIp}/health`,
      description: "try health api",
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

  constructor(scope: Construct, vpc: ec2.Vpc, config: LockerConfig) {
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

    const secretName = "locker-db-master-user-secret";

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

    let schemaBucket = new s3.Bucket(scope, "LockerSchemaBucket", {
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

    this.db_bucket = schemaBucket;

    let migrationCode = readFileSync("lib/aws/card-vault/migration.py", "utf8")
      .replaceAll("{{ACCOUNT}}", process.env.CDK_DEFAULT_ACCOUNT!)
      .replaceAll("{{REGION}}", process.env.CDK_DEFAULT_REGION!);

    const lambdaRole = new iam.Role(scope, "SchemaUploadLambdaRole", {
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
      "LambdaSecurityGroup",
      {
        vpc,
        allowAllOutbound: true,
      },
    );

    db_security_group.addIngressRule(lambdaSecurityGroup, ec2.Port.tcp(5432));

    const initializeUploadFunction = new Function(
      scope,
      "initializeUploadFunction",
      {
        runtime: Runtime.PYTHON_3_9,
        handler: "index.lambda_handler",
        code: Code.fromInline(migrationCode),
        timeout: cdk.Duration.minutes(15),
        role: lambdaRole,
      },
    );

    const db_cluster = new DatabaseCluster(scope, "locker-db-cluster", {
      writer: ClusterInstance.provisioned("Writer Instance", {
        instanceType: ec2.InstanceType.of(
          ec2.InstanceClass.T4G,
          ec2.InstanceSize.MEDIUM,
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
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
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

    const initializeDbTriggerCustomResource = new cdk.CustomResource(
      scope,
      "InitializeDbTriggerCustomResource",
      {
        serviceToken: initializeUploadFunction.functionArn,
      },
    );

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
      timeout: cdk.Duration.minutes(15),
      role: lambdaRole,
    });

    // new triggers.Trigger(scope, "initializeUploadTrigger", {
    //   handler: initializeUploadFunction,
    //   timeout: Duration.minutes(15),
    //   invocationType: triggers.InvocationType.EVENT,
    // }).executeBefore();

    new cdk.triggers.Trigger(scope, "InitializeDBTrigger", {
      handler: initializeDBFunction,
      timeout: cdk.Duration.minutes(15),
      invocationType: cdk.triggers.InvocationType.REQUEST_RESPONSE,
    }).executeAfter(db_cluster);

    initializeDBFunction.node.addDependency(initializeDbTriggerCustomResource);

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
