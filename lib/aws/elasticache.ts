import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as elasticache from 'aws-cdk-lib/aws-elasticache';
import { Construct } from "constructs";
import { Config } from './config';

export class ElasticacheStack {
    cluster: elasticache.CfnCacheCluster;
    constructor(scope: Construct, config: Config, vpc: ec2.Vpc) {
        const subnetgroup = new elasticache.CfnSubnetGroup(scope, 'HSSubnetGroup', {
            description: 'Hyperswitch Elasticache subnet group',
            subnetIds: vpc.publicSubnets.map((subnet) => subnet.subnetId),
        });
        const cluster = new elasticache.CfnCacheCluster(scope, 'HSCacheCluster', {
            clusterName: 'hs-elasticache',
            cacheNodeType: 'cache.t2.micro',
            engine: 'redis',
            numCacheNodes: 1,
            cacheSubnetGroupName: subnetgroup.ref,
            vpcSecurityGroupIds: [vpc.vpcDefaultSecurityGroup], // create a security group for the cache cluster
        });
        this.cluster = cluster;
    }
}
