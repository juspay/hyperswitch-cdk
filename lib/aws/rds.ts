import * as cdk from "aws-cdk-lib";
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Duration, RemovalPolicy, SecretValue } from "aws-cdk-lib";
import {
  ISecurityGroup,
  InstanceType,
  Port,
  SecurityGroup,
  Vpc,
  SubnetType
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

export class DataBaseConstruct {
  sg: SecurityGroup;
  db_cluster: DatabaseCluster;
  password: string;

  constructor(scope: Construct, rds_config: RDSConfig, vpc: Vpc) {
    const engine = DatabaseClusterEngine.auroraPostgres({
      version: AuroraPostgresEngineVersion.VER_13_7,
    });

    const db_name = "hyperswitch";

    const db_security_group = new SecurityGroup(scope, "Hyperswitch-db-SG", {
      securityGroupName: "Hyperswitch-db-SG",
      vpc: vpc,
    });

    this.sg = db_security_group;

    const secretName = "hypers-db-master-user-secret";

    // Create the secret if it doesn't exist
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

    const db_cluster = new DatabaseCluster(scope, "hyperswitch-db-cluster", {
      writer: ClusterInstance.provisioned("Writer Instance", {
        instanceType: InstanceType.of(
          rds_config.writer_instance_class,
          rds_config.writer_instance_size
        ),
        publiclyAccessible: true,
      }),
      readers: [
        ClusterInstance.provisioned("Reader Instance", {
          instanceType: InstanceType.of(
            rds_config.reader_instance_class,
            rds_config.reader_instance_size
          ),
        }),
      ],
      vpc,
      vpcSubnets: { subnetType: SubnetType.PUBLIC },
      engine,
      port: rds_config.port,
      securityGroups: [db_security_group],
      defaultDatabaseName: db_name,
      credentials: Credentials.fromSecret(secret),
      removalPolicy: RemovalPolicy.DESTROY,
    });

    // Add ingress rule to allow traffic from any IP address
    db_cluster.connections.allowFromAnyIpv4(Port.tcp(rds_config.port));

    this.db_cluster = db_cluster;

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
