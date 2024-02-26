import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import { readFileSync } from "fs";
import * as cdk from "aws-cdk-lib";
import * as ssm from "aws-cdk-lib/aws-ssm";

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

export class LockerEc2 extends Construct {
  readonly instance: ec2.Instance;
  sg: ec2.SecurityGroup;
  readonly locker_pair: RsaKeyPair;
  readonly tenant: RsaKeyPair;
  readonly kms_key: kms.Key;
  readonly locker_ssh_key: ec2.CfnKeyPair;

  constructor(scope: Construct, vpc: ec2.IVpc, locker_data: LockerData) {
    super(scope, "LockerEc2");

    const lockerSubnetId: string | undefined =
      scope.node.tryGetContext("locker_subnet_id");

    const kms_key = new kms.Key(this, "locker-kms-key", {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      pendingWindow: cdk.Duration.days(7),
      keyUsage: kms.KeyUsage.ENCRYPT_DECRYPT,
      keySpec: kms.KeySpec.SYMMETRIC_DEFAULT,
      alias: "alias/locker-kms-key",
      description: "KMS key for encrypting the objects in an S3 bucket",
      enableKeyRotation: false,
    });

    const envBucket = new s3.Bucket(this, "LockerEnvBucket", {
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

    const lambda_role = new iam.Role(this, "locker-lambda-role", {
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

    this.tenant = {
      public_key: tenant_public_key
        .export({ type: "spki", format: "pem" })
        .toString(),
      private_key: tenant_private_key
        .export({ type: "pkcs8", format: "pem" })
        .toString(),
    };

    let secret = new Secret(this, "locker-kms-userdata-secret", {
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
        public_key: cdk.SecretValue.unsafePlainText(this.tenant.public_key),
        kms_id: cdk.SecretValue.unsafePlainText(kms_key.keyId),
        region: cdk.SecretValue.unsafePlainText(kms_key.stack.region),
      },
    });

    const encryption_code = readFileSync(
      "lib/aws/card-vault/encryption.py",
    ).toString();

    let env_file = "envfile";

    const kms_encrypt_function = new Function(this, "kms-encrypt", {
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

    const triggerKMSEncryption = new cdk.CustomResource(
      this,
      "KmsEncryptionCR",
      {
        serviceToken: kms_encrypt_function.functionArn,
      },
    );

    const userDataResponse = triggerKMSEncryption.getAtt("message").toString();

    const locker_role = new iam.Role(this, "locker-role", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
      inlinePolicies: {
        "use-kms-sm-s3": kms_policy,
      },
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonS3ReadOnlyAccess"),
      ],
    });

    const sg = new ec2.SecurityGroup(this, "Locker-SG", {
      securityGroupName: "Locker-SG",
      vpc: vpc,
    });

    this.sg = sg;
    let keypair_id = "locker-ec2-keypair";
    const aws_key_pair = new ec2.CfnKeyPair(this, keypair_id, {
      keyName: "Locker-ec2-keypair",
    });

    this.locker_ssh_key = aws_key_pair;

    new cdk.CfnOutput(this, "GetLockerSSHKey", {
      value: `aws ssm get-parameter --name /ec2/keypair/$(aws ec2 describe-key-pairs --filters Name=key-name,Values=${aws_key_pair.keyName} --query "KeyPairs[*].KeyPairId" --output text) --with-decryption --query Parameter.Value --output text > locker.pem`,
    });

    let customData = readFileSync("lib/aws/card-vault/user-data.sh", "utf8")
      .replaceAll("{{BUCKET_NAME}}", envBucket.bucketName)
      .replaceAll("{{ENV_FILE}}", env_file);

    let vpcSubnets: ec2.SubnetSelection;
    if (lockerSubnetId) {
      vpcSubnets = {
        subnets: [
          // ec2.Subnet.fromSubnetId(this, "instanceSubnet", lockerSubnetId),
          ec2.Subnet.fromSubnetAttributes(this, "instanceSubnet", {
            availabilityZone: lockerSubnetId.split(",")[1],
            subnetId: lockerSubnetId.split(",")[0],
          }),
        ],
      };
    } else {
      vpcSubnets = {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      };
    }

    this.instance = new ec2.Instance(this, "locker-ec2", {
      instanceType: ec2.InstanceType.of(
        ec2.InstanceClass.T3,
        ec2.InstanceSize.MEDIUM,
      ),
      // machineImage: new ec2.AmazonLinuxImage(),
      machineImage: new ec2.AmazonLinuxImage({
        generation: ec2.AmazonLinuxGeneration.AMAZON_LINUX_2,
      }),
      vpc,
      vpcSubnets,
      securityGroup: sg,
      keyName: aws_key_pair.keyName,
      allowAllOutbound: true,
      userData: ec2.UserData.custom(customData),
      role: locker_role,
    });

    envBucket.grantRead(this.instance);

    new cdk.CfnOutput(this, "LockerIP", {
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

export class LockerSetup extends Construct {
  locker_ec2: LockerEc2;
  db_cluster: DatabaseCluster;
  db_sg: SecurityGroup;
  // db_bucket: s3.Bucket;

  constructor(
    scope: Construct,
    vpc: ec2.IVpc,
    config: LockerConfig
  ) {
    super(scope, "LockerSetup");
    // Provide Subnet For Locker from Context
    const lockerdbSubnetId: string | undefined = scope.node.tryGetContext(
      "locker_db_subnet_id",
    );

    cdk.Tags.of(this).add("SubStack", "Locker");

    // Creating Database for LockerData
    const engine = DatabaseClusterEngine.auroraPostgres({
      version: AuroraPostgresEngineVersion.VER_13_7,
    });

    const db_name = "locker";

    const db_security_group = new SecurityGroup(this, "Locker-db-SG", {
      securityGroupName: "Locker-db-SG",
      vpc: vpc,
    });

    this.db_sg = db_security_group;

    const secretName = "LockerDbMasterUserSecret";

    // Create the secret if it doesn't exist
    let secret = new Secret(this, "locker-db-master-user-secret", {
      secretName: secretName,
      description: "Database master user credentials",
      secretObjectValue: {
        dbname: cdk.SecretValue.unsafePlainText(db_name),
        username: cdk.SecretValue.unsafePlainText(config.db_user),
        password: cdk.SecretValue.unsafePlainText(config.db_pass),
      },
    });

    let vpcSubnetsDb: ec2.SubnetSelection;
    if (lockerdbSubnetId) {
      vpcSubnetsDb = {
        subnets: [
          ec2.Subnet.fromSubnetAttributes(this, "instancedbSubnet1", {
            subnetId: lockerdbSubnetId.split(",")[0],
            availabilityZone: lockerdbSubnetId.split(",")[1],
          }),

          ec2.Subnet.fromSubnetAttributes(this, "instancedbSubnet2", {
            subnetId: lockerdbSubnetId.split(",")[2],
            availabilityZone: lockerdbSubnetId.split(",")[3],
          }),
        ],
      };
    } else {
      vpcSubnetsDb = {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      };
    }

    const db_cluster = new DatabaseCluster(this, "locker-db-cluster", {
      writer: ClusterInstance.provisioned("Writer Instance", {
        instanceType: ec2.InstanceType.of(
          ec2.InstanceClass.T4G,
          ec2.InstanceSize.MEDIUM,
        ),
      }),
      vpc,
      vpcSubnets: vpcSubnetsDb,
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

    this.locker_ec2 = new LockerEc2(this, vpc, {
      master_key: config.master_key,
      database: {
        user: config.db_user,
        password: config.db_pass,
        host: db_cluster.clusterEndpoint.hostname,
      },
    });

    this.locker_ec2.addServer(this.db_sg, ec2.Port.tcp(5432));

    const unixTs = new Date().valueOf();

    const hyperswitch_private_key = new ssm.StringParameter(
      this,
      "TenantPrivateKeySP",
      {
        parameterName: `/tenant/private_key-${unixTs}`,
        stringValue: this.locker_ec2.tenant.private_key,
      },
    );

    const locker_public_key = new ssm.StringParameter(
      this,
      "LockerPublicKeySP",
      {
        parameterName: `/locker/public_key-${unixTs}`,
        stringValue: this.locker_ec2.locker_pair.public_key,
      },
    );

    new cdk.CfnOutput(this, "LockerPublicKey", {
      value: `aws ssm get-parameter --name ${locker_public_key.parameterName}:1 --query 'Parameter.Value' --output text`,
    });

    new cdk.CfnOutput(this, "TenantPrivateKey", {
      value: `aws ssm get-parameter --name ${hyperswitch_private_key.parameterName}:1 --query 'Parameter.Value' --output text`,
    });
  }
}
