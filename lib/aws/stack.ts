import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import { Config } from "./config";
import { Vpc } from "./networking";
import { ElasticacheStack } from "./elasticache";
import { DataBaseConstruct } from "./rds";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import { EksStack } from "./eks";
import { SubnetStack } from "./subnet";
import { EC2Instance } from "./ec2";
import { HyperswitchSDKStack } from "./hs_sdk";

export class AWSStack extends cdk.Stack {
  constructor(scope: Construct, config: Config) {
    const aws_arn = scope.node.tryGetContext("aws_arn");
    const is_root_user = aws_arn.includes(":root");
    if(is_root_user)
      throw new Error("Please create new user with appropiate role as ROOT user is not recommended");
    super(scope, config.stack.name, {stackName: config.stack.name});

    let vpc = new Vpc(this, config.vpc);
    let subnets = new SubnetStack(this, vpc.vpc, config);
    let elasticache = new ElasticacheStack(this, config, vpc.vpc);
    let rds = new DataBaseConstruct( this, config.rds ,vpc.vpc);
    rds.sg.addIngressRule(ec2.Peer.ipv4('0.0.0.0/0'), ec2.Port.tcp(5432)); // this is required to connect db from local

    update_config(config, rds.db_cluster.clusterEndpoint.hostname, elasticache.cluster.attrRedisEndpointAddress)

    let isStandalone = scope.node.tryGetContext('test') || false;
    if (isStandalone){
      console.log("Deploying Standalone")
      let hyperswitch_ec2 = new EC2Instance(this, vpc.vpc, config);
      rds.sg.addIngressRule(hyperswitch_ec2.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(hyperswitch_ec2.sg, ec2.Port.tcp(6379));
      hyperswitch_ec2.sg.addEgressRule(rds.sg, ec2.Port.tcp(5432));
      hyperswitch_ec2.sg.addEgressRule(elasticache.sg, ec2.Port.tcp(6379));
      hyperswitch_ec2.sg.addIngressRule(ec2.Peer.ipv4('0.0.0.0/0'), ec2.Port.tcp(80));
      hyperswitch_ec2.sg.addIngressRule(ec2.Peer.ipv4('0.0.0.0/0'), ec2.Port.tcp(22));
    }else{
      console.log("Deploying production")
      let eks = new EksStack(this, config, vpc.vpc, rds, elasticache, config.hyperswitch_ec2.admin_api_key);
      rds.sg.addIngressRule(eks.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(eks.sg, ec2.Port.tcp(6379));
      let hsSdk = new HyperswitchSDKStack(this, config, vpc.vpc, rds);
    }
  }
}

function update_config(config:Config, db_host:string, redis_host:string){
  config.hyperswitch_ec2.db_host = db_host;
  config.hyperswitch_ec2.redis_host = redis_host;
  return config;
}