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
    const vpc = new ec2.Vpc(scope, config.name, {
      maxAzs: config.maxAzs,
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
        {
          name: "eks-worker-nodes-one-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 22,
        },
        {
          name: "utils-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: "management-zone",
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: "locker-database-zone",
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
        {
          name: "service-layer-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: "data-stack-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: "external-incoming-zone",
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: "database-zone",
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
        {
          name: "outgoing-proxy-lb-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: "outgoing-proxy-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: "locker-server-zone",
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
        {
          name: "elasticache-zone",
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
        {
          name: "incoming-npci-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: "eks-control-plane-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: "incoming-web-envoy-zone",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
      ],
      ipAddresses: ec2.IpAddresses.cidr("10.63.0.0/16"),
    });

    this.vpc = vpc;
  }
}

