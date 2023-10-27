import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as elasticache from 'aws-cdk-lib/aws-elasticache';
import { Construct } from "constructs";
import { Config } from './config';
import { SecurityGroup } from 'aws-cdk-lib/aws-ec2';

export class ElasticacheStack {
    cluster: elasticache.CfnCacheCluster;
    sg: ec2.SecurityGroup;
    constructor(scope: Construct, config: Config, vpc: ec2.Vpc) {
        const elasticache_security_group = new SecurityGroup(scope, "Hyperswitch-elasticache-SG", {
            securityGroupName: "Hyperswitch-elasticache-SG",
            vpc: vpc,
          });

          this.sg = elasticache_security_group;

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
            vpcSecurityGroupIds: [elasticache_security_group.securityGroupId], // create a security group for the cache cluster
        });
        this.cluster = cluster;
    }
}
