import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';
import { Config } from './config';

export class SubnetStack {
    constructor(scope: Construct , vpc: ec2.Vpc, config: Config) {
        config.extra_subnets.forEach((subnetConfig) => {
            const subnet = new ec2.Subnet(scope, subnetConfig.id, {
                vpcId: vpc.vpcId,
                cidrBlock: subnetConfig.cidr,
                availabilityZone: vpc.availabilityZones[0],
            });
        });
    }
}
