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
            cacheNodeType: 'cache.t3.micro',
            engine: 'redis',
            numCacheNodes: 1,
            
            // cacheParameterGroupName : 'default.redis7.cluster.on',
            cacheSubnetGroupName: subnetgroup.ref,
            vpcSecurityGroupIds: [elasticache_security_group.securityGroupId], // create a security group for the cache cluster
        });

        // const cluster = new elasticache.CfnReplicationGroup(
        //     scope,
        //     `RedisReplicaGroup`,
        //     {
        //         engine: "redis",
        //         cacheNodeType: "cache.m4.xlarge",
        //         replicasPerNodeGroup: 1,
        //         numNodeGroups: 3,
        //         automaticFailoverEnabled: true,
        //         autoMinorVersionUpgrade: true,
        //         replicationGroupDescription: "cluster redis",
        //         cacheSubnetGroupName: subnetgroup.ref,
        //         cacheParameterGroupName: "default.redis7.cluster.on",
        //     }
        // )
        this.cluster = cluster;


    }
}
