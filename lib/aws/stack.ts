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

export class AWSStack extends cdk.Stack {
  constructor(scope: Construct, config: Config) {
    super(scope, config.stack.name);
    let vpc = new Vpc(this, config.vpc);
    let subnets = new SubnetStack(this, vpc.vpc, config);
    let elasticache = new ElasticacheStack(this, config, vpc.vpc);
    let rds = new DataBaseConstruct( this, // create database master user secret and store it in Secrets Manager
      {
        port: 5432,
        password: scope.node.tryGetContext('Please Enter DB password') || 'db_pass',
        writer_instance_class: ec2.InstanceClass.T3,
        writer_instance_size: ec2.InstanceSize.MEDIUM,
        reader_instance_class: ec2.InstanceClass.T3,
        reader_instance_size: ec2.InstanceSize.MEDIUM,
      },
      vpc.vpc
    );
    let eks = new EksStack(this, config, vpc.vpc, rds, elasticache);
    rds.sg.addIngressRule(eks.sg, ec2.Port.tcp(5432));
    try{
      rds.sg.addIngressRule(ec2.Peer.ipv4('0.0.0.0/0'), ec2.Port.tcp(5432)); // this is required for running schema and to connect to db from local
    }catch(e){
      console.log(e);
    }
    // elasticache.sg.addIngressRule(eks.sg, ec2.Port.tcp(6379)); //Enable this post added security group to elasticache
  }
}
