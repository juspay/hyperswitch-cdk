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
    let db_pass = scope.node.tryGetContext('db_pass') || "dbpassword";
    let admin_api_key = scope.node.tryGetContext('admin_api_key') || "test_admin"
    let isStandalone = scope.node.tryGetContext('test') || false;
    let rds = new DataBaseConstruct( this, // create database master user secret and store it in Secrets Manager
      {
        port: 5432,
        db_user: "db_user",
        password: db_pass,
        writer_instance_class: ec2.InstanceClass.T3,
        writer_instance_size: ec2.InstanceSize.MEDIUM,
        reader_instance_class: ec2.InstanceClass.T3,
        reader_instance_size: ec2.InstanceSize.MEDIUM,
      },
      vpc.vpc
    );
    rds.sg.addIngressRule(ec2.Peer.ipv4('0.0.0.0/0'), ec2.Port.tcp(5432)); // this is required to connect db from local

    if (isStandalone){
      console.log("Deploying Standalone")
      let db_host = rds.db_cluster.clusterEndpoint.hostname;
      let hyperswitch_ec2 = new EC2Instance(this, vpc.vpc, "hyperswitch", elasticache.cluster.attrRedisEndpointAddress, db_host, db_pass, admin_api_key, "db_user", "hyperswitch");
      rds.sg.addIngressRule(hyperswitch_ec2.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(hyperswitch_ec2.sg, ec2.Port.tcp(6379));
      hyperswitch_ec2.sg.addEgressRule(rds.sg, ec2.Port.tcp(5432));
      hyperswitch_ec2.sg.addEgressRule(elasticache.sg, ec2.Port.tcp(6379));
      hyperswitch_ec2.sg.addIngressRule(ec2.Peer.ipv4('0.0.0.0/0'), ec2.Port.tcp(80));
      hyperswitch_ec2.sg.addIngressRule(ec2.Peer.ipv4('0.0.0.0/0'), ec2.Port.tcp(22));
    }else{
      console.log("Deploying production")
      let eks = new EksStack(this, config, vpc.vpc, rds, elasticache, admin_api_key);
      rds.sg.addIngressRule(eks.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(eks.sg, ec2.Port.tcp(6379));
    }


  }
}
