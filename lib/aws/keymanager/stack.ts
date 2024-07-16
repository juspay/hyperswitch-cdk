import * as cdk from "aws-cdk-lib";
import { IVpc, InstanceType, SecurityGroup } from "aws-cdk-lib/aws-ec2";
import { Vpc, SubnetNames } from "../networking";
import * as ec2 from "aws-cdk-lib/aws-ec2";

import * as eks from "aws-cdk-lib/aws-eks";
import {
    AuroraPostgresEngineVersion,
    DatabaseClusterEngine,
    ClusterInstance,
    DatabaseCluster,
    Credentials,
} from "aws-cdk-lib/aws-rds";
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
}

export class Keymanager extends cdk.Stack {
    vpc: IVpc;
    constructor(scope: Construct, config: KeymanagerConfig, cluster: eks.Cluster) {
        super(scope, config.name, {
            env: {
                account: process.env.CDK_DEFAULT_ACCOUNT,
                region: process.env.CDK_DEFAULT_REGION
            },
            stackName: config.name,
        });

        cdk.Tags.of(this).add("Stack", "Hyperswitch");
        cdk.Tags.of(this).add("StackName", config.name);

        let vpc = new Vpc(this, config.vpc);
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

        const keymanagerChart = cluster.addHelmChart("KeymanagerService", {
            chart: "hyperswitch-keymanager",
            repository: "https://juspay.github.io/hyperswitch-helm/v0.1.2",
            namespace: "keymanager",
            release: "keymanager",
            wait: true,
            values: {
                server: {
                    secrets: {
                        iam_role: kms_role.roleArn,
                        region: process.env.CDK_DEFAULT_REGION,
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
                            password: config.db_pass,
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
            readers: [
                ClusterInstance.provisioned("Reader Instance", {
                    instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MEDIUM),
                })
            ],
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
