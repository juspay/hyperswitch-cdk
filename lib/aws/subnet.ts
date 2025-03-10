import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import { Config } from "./config";
import { RemovalPolicy } from "aws-cdk-lib";

export class SubnetStack {
  constructor(scope: Construct, vpc: ec2.Vpc, config: Config) {
    config.extra_subnets.forEach((subnetConfig) => {
      const subnet = new ec2.Subnet(scope, subnetConfig.id, {
        vpcId: vpc.vpcId,
        cidrBlock: subnetConfig.cidr,
        availabilityZone: vpc.availabilityZones[0],
      });
    });
  }
}

export class DefaultRemoverStack extends Construct {
  constructor(scope: Construct, config: Config) {
    super(scope, "DefaultRemovalStack");

    /// Early return if the default subnet is not to be removed
    if (!config.subnet.remove_default) {
      return;
    }

    const vpc = ec2.Vpc.fromLookup(this, "VPC", {
      isDefault: true,
    });

    vpc.applyRemovalPolicy(RemovalPolicy.DESTROY);
  }
}
