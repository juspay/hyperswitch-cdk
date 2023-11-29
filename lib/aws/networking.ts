import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { SubnetConfigs, VpcConfig } from "./config";
import { Construct } from "constructs";

export enum SubnetNames {
  PublicSubnet = "public-subnet-1",
  IsolatedSubnet = "isolated-subnet-1",
  DatabaseSubnet = "database-isolated-subnet-1"
}

export class Vpc {
  vpc: ec2.Vpc;
  constructor(scope: Construct, config: VpcConfig) {
    const vpc = new ec2.Vpc(scope, "app-vpc", {
      // availabilityZones: config.availabilityZones,
      maxAzs: 2,
      subnetConfiguration: [
        {
          name: SubnetNames.PublicSubnet,
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: SubnetNames.IsolatedSubnet,
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: SubnetNames.DatabaseSubnet,
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
      ],
    });

    new cdk.CfnOutput(scope, "VPC id: ", {
      value: vpc.vpcId,
    });

    this.vpc = vpc;
  }
}

