import * as cdk from "aws-cdk-lib";
import { IVpc, InstanceType, SecurityGroup } from "aws-cdk-lib/aws-ec2";
import { Vpc, SubnetNames } from "../networking";
import * as ec2 from "aws-cdk-lib/aws-ec2";

import * as ssm from 'aws-cdk-lib/aws-ssm';
import * as eks from "aws-cdk-lib/aws-eks";
import {
    AuroraPostgresEngineVersion,
    DatabaseClusterEngine,
    ClusterInstance,
    DatabaseCluster,
    Credentials,
} from "aws-cdk-lib/aws-rds";

import { Code, Function, Runtime } from "aws-cdk-lib/aws-lambda";

import { readFileSync } from "fs";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import { SubnetStack } from "../subnet";

import * as iam from "aws-cdk-lib/aws-iam";
import * as kms from "aws-cdk-lib/aws-kms";
import { VpcConfig } from "../config";
import { Construct } from "constructs";

export type KeymanagerConfig = {
    vpc: VpcConfig,
    name: string;
    db_user: string;
    db_pass: string;
    ca_cert: string;
    tls_key: string;
    tlk_cert: string;
}

export class Keymanager extends cdk.Stack {
    constructor(scope: Construct, config: KeymanagerConfig, vpc: Vpc, cluster: eks.Cluster) {
        super(scope, config.name, {
            env: {
                account: process.env.CDK_DEFAULT_ACCOUNT,
                region: process.env.CDK_DEFAULT_REGION
            },
            stackName: config.name,
        });

        cdk.Tags.of(this).add("Stack", "Hyperswitch");
        cdk.Tags.of(this).add("StackName", config.name);

        const kms_key = new kms.Key(scope, "keymanager-kms-key", {
            removalPolicy: cdk.RemovalPolicy.DESTROY,
            pendingWindow: cdk.Duration.days(7),
            keyUsage: kms.KeyUsage.ENCRYPT_DECRYPT,
            keySpec: kms.KeySpec.SYMMETRIC_DEFAULT,
            alias: "alias/keymanager-kms-key",
            description: "KMS key for encrypting the key for Keymanager",
            enableKeyRotation: false,
        });
        let db = new KeymanagerDB(scope, vpc.vpc);
        let kms_iam_policy = new iam.PolicyDocument({
            statements: [new iam.PolicyStatement({
                actions: [
                    "kms:Encrypt",
                    "kms:Decrypt",
                    "kms:GenerateDataKey"
                ],
                resources: [kms_key.keyArn]
            })]
        });

        const kms_role = new iam.Role(this, "keymanager-kms-role", {
            assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
            inlinePolicies: {
                "kms-role": kms_iam_policy,
            }
        });

        const kms_policy_document = new iam.PolicyDocument({
            statements: [
                new iam.PolicyStatement({
                    actions: ["kms:*"],
                    resources: [kms_key.keyArn],
                }),
                new iam.PolicyStatement({
                    actions: ["elasticloadbalancing:DeleteLoadBalancer",
                        "elasticloadbalancing:DescribeLoadBalancers"],
                    resources: ["*"],
                }),
                new iam.PolicyStatement({
                    actions: ["ssm:*"],
                    resources: ["*"],
                }),
                new iam.PolicyStatement({
                    actions: ["secretsmanager:*"],
                    resources: ["*"],
                }),
            ],
        });
        const lambda_role = new iam.Role(scope, "hyperswitch-lambda-role", {
            assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
            inlinePolicies: {
                "use-kms-sm": kms_policy_document,
            },
        });
        const encryption_code = readFileSync(
            "lib/aws/keymanager/encryption.py",
        ).toString();

        let secret = new Secret(scope, "keymanager-kms-userdata-secret", {
            secretName: "KeymanagerKmsDataSecret",
            description: "KMS encryptable secrets for Keymanager",
            secretObjectValue: {
                db_password: cdk.SecretValue.unsafePlainText(
                    config.db_pass,
                ),
                kms_id: cdk.SecretValue.unsafePlainText(kms_key.keyId),
                region: cdk.SecretValue.unsafePlainText(kms_key.stack.region),
                ca_cert: cdk.SecretValue.unsafePlainText(config.ca_cert),
                tls_key: cdk.SecretValue.unsafePlainText(config.tls_key),
                tls_cert: cdk.SecretValue.unsafePlainText(config.tlk_cert),
            },
        });

        const kms_encrypt_function = new Function(scope, "keymanager-kms-encrypt", {
            functionName: "KeymanagerKmsEncryptionLambda",
            runtime: Runtime.PYTHON_3_9,
            handler: "index.lambda_handler",
            code: Code.fromInline(encryption_code),
            timeout: cdk.Duration.minutes(15),
            role: lambda_role,
            environment: {
                SECRET_MANAGER_ARN: secret.secretArn,
            },
        });

        const triggerKMSEncryption = new cdk.CustomResource(
            scope,
            "KeymanagerKmsEncryptionCR",
            {
                serviceToken: kms_encrypt_function.functionArn,
            },
        );

        const kmsSecrets = new KmsSecrets(scope, triggerKMSEncryption);
        const keymanagerChart = cluster.addHelmChart("KeymanagerService", {
            chart: "hyperswitch-keymanager",
            repository: "https://juspay.github.io/hyperswitch-helm/v0.1.2",
            namespace: "keymanager",
            release: "keymanager",
            createNamespace: true,
            wait: true,
            values: {
                server: {
                    secrets: {
                        iam_role: kms_role.roleArn,
                        region: process.env.CDK_DEFAULT_REGION,
                        ca_cert: kmsSecrets.kms_encrypted_ca_cert,
                        tls_key: kmsSecrets.kms_encrypted_tls_key,
                        tls_cert: kmsSecrets.kms_encrypted_tls_cert,
                    }
                },
                postgresql: {
                    enable: false
                },
                external: {
                    postgresql: {
                        enabled: true,
                        config: {
                            host: db.dbCluster?.clusterEndpoint.hostname,
                            port: 5432,
                            username: config.db_user,
                            password: kmsSecrets.kms_encrypted_db_pass,
                            database: "keymanager_db",
                        }
                    }
                }
            }
        });
    }
}

export class KeymanagerDB extends Construct {
    sg: SecurityGroup;
    dbCluster: DatabaseCluster;
    constructor(scope: Construct, vpc: ec2.IVpc) {
        super(scope, "KeymanagerStack");

        const db_name = "keymanager_db";

        let security_group = new SecurityGroup(scope, "Keymanager-DB-SG", {
            securityGroupName: "Keymanager-DB-SG",
            vpc: vpc,
        });

        this.sg = security_group;

        const secretName = "keymanager-db-secret";

        let secret = new Secret(scope, "keymanager-db-secret", {
            secretName: secretName,
            description: "Database Secret credentials",
            secretObjectValue: {
                dbName: cdk.SecretValue.unsafePlainText(db_name),
            },
        });

        const engine = DatabaseClusterEngine.auroraPostgres({
            version: AuroraPostgresEngineVersion.VER_14_5,
        });

        const dbCluster = new DatabaseCluster(scope, "keymanager-db-cluster", {
            writer: ClusterInstance.provisioned("Writer Instance", {
                instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MEDIUM),
                publiclyAccessible: false
            }),
            vpc,
            vpcSubnets: { subnetGroupName: "database-zone" },
            engine,
            storageEncrypted: true,
            securityGroups: [security_group],
            defaultDatabaseName: db_name,
            credentials: Credentials.fromSecret(secret),
        })

        this.dbCluster = dbCluster;
    }
}


class KmsSecrets {
    readonly kms_encrypted_tls_key: string;
    readonly kms_encrypted_tls_cert: string;
    readonly kms_encrypted_db_pass: string;
    readonly kms_encrypted_ca_cert: string;

    constructor(scope: Construct, kms: cdk.CustomResource) {

        let message = kms.getAtt("message");
        this.kms_encrypted_db_pass = ssm.StringParameter.valueForStringParameter(scope, "/keymanager/db_pass", 1);
        this.kms_encrypted_tls_cert = ssm.StringParameter.valueForStringParameter(scope, "/keymanager/tls_cert", 1);
        this.kms_encrypted_tls_key = ssm.StringParameter.valueForStringParameter(scope, "/keymanager/tls_key", 1);
        this.kms_encrypted_ca_cert = ssm.StringParameter.valueForStringParameter(scope, "/keymanager/ca_cert", 1);
    }
}
