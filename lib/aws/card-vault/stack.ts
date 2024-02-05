import * as cdk from "aws-cdk-lib";
import { IVpc, InstanceType, SecurityGroup } from "aws-cdk-lib/aws-ec2";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { PolicyStatement, Role, ServicePrincipal } from "aws-cdk-lib/aws-iam";
import * as iam from "aws-cdk-lib/aws-iam";
import { Function, Code, Runtime } from "aws-cdk-lib/aws-lambda";

import { Bucket } from "aws-cdk-lib/aws-s3";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as ssm from "aws-cdk-lib/aws-ssm";

import { Construct } from "constructs";
import { readFileSync } from "fs";
import { LockerSetup } from "./components";
import { EC2Instance } from "../ec2";
import { Vpc } from "../networking";
import { SubnetStack } from "../subnet";

export type StandaloneLockerConfig = {
  vpc_id: string | undefined;
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

    if (config.vpc_id) {
      this.vpc = ec2.Vpc.fromLookup(this, "TheVpc", {
        vpcId: config.vpc_id,
      });
    } else {
      const vpc = new Vpc(this, {
        name: "locker-standalone",
        maxAzs: 2
      });

      this.vpc = vpc.vpc;
    }

    let locker = new LockerSetup(
      this,
      this.vpc,
      {
        db_pass: config.db_pass,
        db_user: config.db_user,
        master_key: config.master_key,
      },
    );

    this.locker = locker;

    const display_rds_endpoint = new cdk.CfnOutput(this, "RdsEndpoint", {
      value: this.locker.db_cluster.clusterEndpoint.hostname,
    });

    display_rds_endpoint.node.addDependency(this.locker);

    if (
      this.node.tryGetContext("locker_jump") == undefined ||
      this.node.tryGetContext("locker_jump") == "true"
    ) {
      let jump_sg = new ec2.SecurityGroup(this, "locker-jump-sg", {
        securityGroupName: "locker-jump-sg",
        vpc: this.vpc,
      });

      this.locker.locker_ec2.addClient(jump_sg, ec2.Port.tcp(22));
      this.locker.locker_ec2.addClient(jump_sg, ec2.Port.tcp(8080));
      jump_sg.addIngressRule(ec2.Peer.ipv4("0.0.0.0/0"), ec2.Port.tcp(22));

      const jump_key = new ec2.CfnKeyPair(this, "jump-server-key", {
        keyName: "LockerJump-ec2-keypair",
      });

      let jump_server = new ec2.Instance(this, "Locker Jump Server", {
        instanceType: ec2.InstanceType.of(
          ec2.InstanceClass.T3,
          ec2.InstanceSize.MEDIUM,
        ),
        machineImage: new ec2.AmazonLinuxImage({
          generation: ec2.AmazonLinuxGeneration.AMAZON_LINUX_2,
        }),
        vpc: this.vpc,
        vpcSubnets: {
          subnetType: ec2.SubnetType.PUBLIC,
        },
        associatePublicIpAddress: true,
        securityGroup: jump_sg,
        keyName: jump_key.keyName,
      });

      new cdk.CfnOutput(this, "GetJumpLockerSSHKey", {
        value: `aws ssm get-parameter --name /ec2/keypair/$(aws ec2 describe-key-pairs --filters Name=key-name,Values=${jump_key.keyName} --query "KeyPairs[*].KeyPairId" --output text) --with-decryption --query Parameter.Value --output text > locker-jump.pem`,
      });

      const value = new cdk.CfnOutput(this, "JumpLockerPublicIP", {
        value: `${jump_server.instancePublicIp}`,
      });

      value.node.addDependency(jump_server);
    }
  }
}
