import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import { Config, EC2Config } from "./config";
import { Vpc, SubnetNames } from "./networking";
import { ElasticacheStack } from "./elasticache";
import { DataBaseConstruct } from "./rds";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import { readFileSync } from "fs";
import { EksStack } from "./eks";
import { SubnetStack } from "./subnet";
import { EC2Instance } from "./ec2";
import { LockerSetup } from "./card-vault/components";

export class AWSStack extends cdk.Stack {
  constructor(scope: Construct, config: Config) {
    super(scope, config.stack.name, {
      // env: {
      //   account: process.env.CDK_DEFAULT_ACCOUNT,
      //   region: process.env.CDK_DEFAULT_REGION
      // },
      stackName: config.stack.name,
    });

    cdk.Tags.of(this).add("Stack", "Hyperswitch");
    cdk.Tags.of(this).add("StackName", config.stack.name);

    Object.entries(config.tags).forEach(([key, value]) => {
      cdk.Tags.of(this).add(key, value);
    });

    let isStandalone = scope.node.tryGetContext("free_tier") == "true" || false;
    let vpc = new Vpc(this, config.vpc);
    let subnets = new SubnetStack(this, vpc.vpc, config);
    let elasticache = new ElasticacheStack(this, config, vpc.vpc);
    let rds = new DataBaseConstruct(this, config.rds, vpc.vpc, isStandalone);
    let locker: LockerSetup | undefined;
    if (config.locker.master_key) {
      locker = new LockerSetup(this, vpc.vpc, config.locker);
    }

    if (isStandalone) {
      // Deploying Router and Control center application in a single EC2 instance
      let hyperswitch_ec2 = new EC2Instance(
        this,
        vpc.vpc,
        get_standalone_ec2_config(config),
      );
      rds.sg.addIngressRule(hyperswitch_ec2.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(hyperswitch_ec2.sg, ec2.Port.tcp(6379));
      hyperswitch_ec2.sg.addEgressRule(rds.sg, ec2.Port.tcp(5432));
      hyperswitch_ec2.sg.addEgressRule(elasticache.sg, ec2.Port.tcp(6379));
      hyperswitch_ec2.sg.addIngressRule(
        // To access the Router
        ec2.Peer.ipv4("0.0.0.0/0"),
        ec2.Port.tcp(80),
      );
      hyperswitch_ec2.sg.addIngressRule(
        // To access the Control Center
        ec2.Peer.ipv4("0.0.0.0/0"),
        ec2.Port.tcp(9000),
      );
      hyperswitch_ec2.sg.addIngressRule(
        // To SSH into the instance
        ec2.Peer.ipv4("0.0.0.0/0"),
        ec2.Port.tcp(22),
      );

      // Deploying SDK and Demo app in a single EC2 instance
      let hyperswitch_sdk_ec2 = new EC2Instance(
        this,
        vpc.vpc,
        get_standalone_sdk_ec2_config(config, hyperswitch_ec2),
        hyperswitch_ec2.getInstance(),
      );

      // create an security group for the SDK and add rules to access the router and demo app with port 1234 after the hyperswitch_sdk_ec2 is created
      hyperswitch_sdk_ec2.sg.addIngressRule(
        // To access the SDK
        ec2.Peer.ipv4("0.0.0.0/0"),
        ec2.Port.tcp(9090),
      );
      hyperswitch_sdk_ec2.sg.addIngressRule(
        // To Access Demo APP
        ec2.Peer.ipv4("0.0.0.0/0"),
        ec2.Port.tcp(5252),
      );
      hyperswitch_sdk_ec2.sg.addIngressRule(
        // To SSH into the instance
        ec2.Peer.ipv4("0.0.0.0/0"),
        ec2.Port.tcp(22),
      );

      new cdk.CfnOutput(this, "StandaloneURL", {
        value:
          "http://" +
          hyperswitch_ec2.getInstance().instancePublicIp +
          "/health",
      });
      new cdk.CfnOutput(this, "ControlCenterURL", {
        value:
          "http://" +
          hyperswitch_ec2.getInstance().instancePublicIp +
          ":9000" +
          "\nFor login, use email id as 'itisatest@gmail.com' and password is admin",
      });
      new cdk.CfnOutput(this, "SdkAssetsURL", {
        value:
          "http://" +
          hyperswitch_sdk_ec2.getInstance().instancePublicIp +
          ":9090",
      });
      new cdk.CfnOutput(this, "DemoApp", {
        value:
          "http://" +
          hyperswitch_sdk_ec2.getInstance().instancePublicIp +
          ":5252",
      });
    } else {
      const aws_arn = scope.node.tryGetContext("aws_arn");
      const is_root_user = aws_arn.includes(":root");
      if (is_root_user)
        throw new Error(
          "Please create new user with appropiate role as ROOT user is not recommended",
        );

      if (rds.dbCluster) {
        config = update_config(
          config,
          rds.dbCluster.clusterEndpoint.hostname,
          elasticache.cluster.attrRedisEndpointAddress,
        );
      }
      let eks = new EksStack(
        this,
        config,
        vpc.vpc,
        rds,
        elasticache,
        config.hyperswitch_ec2.admin_api_key,
        locker,
      );
      if (locker) locker.locker_ec2.addClient(eks.sg, ec2.Port.tcp(8080));
      rds.sg.addIngressRule(eks.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(eks.sg, ec2.Port.tcp(6379));
      // let hsSdk = new HyperswitchSDKStack(this, config, vpc.vpc, rds, eks);

      // Create Jumps and add rules to access RDS, Elasticache and Proxies
      // Internal Jump can be accessed only from external jump. External jump can be accessed only from Session Manager
      let internal_jump = new EC2Instance(
        this,
        vpc.vpc,
        get_internal_jump_ec2_config(config, "hyperswitch_internal_jump_ec2"),
      );
      let external_jump = new EC2Instance(
        this,
        vpc.vpc,
        get_external_jump_ec2_config(config, "hyperswitch_external_jump_ec2"),
      );
      external_jump.sg.addEgressRule(internal_jump.sg, ec2.Port.tcp(22));
      internal_jump.sg.addIngressRule(external_jump.sg, ec2.Port.tcp(22));
      internal_jump.sg.addEgressRule(rds.sg, ec2.Port.tcp(5432));
      internal_jump.sg.addEgressRule(elasticache.sg, ec2.Port.tcp(6379));
      external_jump.sg.addIngressRule(
        ec2.Peer.ipv4("0.0.0.0/0"),
        ec2.Port.tcp(22),
      );

      if (locker)
        locker.locker_ec2.addClient(internal_jump.sg, ec2.Port.tcp(22));
      if (locker)
        locker.db_sg.addIngressRule(internal_jump.sg, ec2.Port.tcp(5432));
      if (locker)
        internal_jump.sg.addEgressRule(locker.db_sg, ec2.Port.tcp(5432));

      rds.sg.addIngressRule(internal_jump.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(internal_jump.sg, ec2.Port.tcp(6379));
    }
  }
}

function update_config(config: Config, db_host: string, redis_host: string) {
  config.hyperswitch_ec2.db_host = db_host;
  config.hyperswitch_ec2.redis_host = redis_host;
  return config;
}

function get_standalone_ec2_config(config: Config) {
  let customData = readFileSync("lib/aws/userdata.sh", "utf8")
    .replaceAll("{{redis_host}}", config.hyperswitch_ec2.redis_host)
    .replaceAll("{{db_host}}", config.hyperswitch_ec2.db_host)
    .replaceAll("{{password}}", config.rds.password)
    .replaceAll("{{admin_api_key}}", config.hyperswitch_ec2.admin_api_key)
    .replaceAll("{{db_username}}", config.rds.db_user)
    .replaceAll("{{db_name}}", config.rds.db_name);
  let ec2_config: EC2Config = {
    id: "hyperswitch_standalone_app_cc_ec2",
    instanceType: ec2.InstanceType.of(
      ec2.InstanceClass.T2,
      ec2.InstanceSize.MICRO,
    ),
    machineImage: new ec2.AmazonLinuxImage(),
    vpcSubnets: { subnetGroupName: SubnetNames.PublicSubnet },
    userData: ec2.UserData.custom(customData),
  };
  return ec2_config;
}

function get_standalone_sdk_ec2_config(
  config: Config,
  hyperswitch_ec2: EC2Instance,
) {
  let customData = readFileSync("lib/aws/sdk_userdata.sh", "utf8")
    .replaceAll(
      "{{router_host}}",
      hyperswitch_ec2.getInstance().instancePublicIp,
    )
    .replaceAll("{{admin_api_key}}", config.hyperswitch_ec2.admin_api_key)
    .replaceAll("{{version}}", "0.16.7")
    .replaceAll("{{sub_version}}", "v0");
  let ec2_config: EC2Config = {
    id: "hyperswitch_standalone_sdk_demo_ec2",
    instanceType: ec2.InstanceType.of(
      ec2.InstanceClass.T2,
      ec2.InstanceSize.MICRO,
    ),
    machineImage: new ec2.AmazonLinuxImage(),
    vpcSubnets: { subnetGroupName: SubnetNames.PublicSubnet },
    userData: ec2.UserData.custom(customData),
  };
  return ec2_config;
}

function get_internal_jump_ec2_config(config: Config, id: string) {
  let ec2_config: EC2Config = {
    id,
    instanceType: ec2.InstanceType.of(
      ec2.InstanceClass.T3,
      ec2.InstanceSize.MEDIUM,
    ),
    machineImage: new ec2.AmazonLinuxImage(),
    vpcSubnets: { subnetGroupName: SubnetNames.PublicSubnet },
    associatePublicIpAddress: false,
  };
  return ec2_config;
}

function get_external_jump_ec2_config(config: Config, id: string) {
  let props: ec2.AmazonLinuxImageProps = {
    generation: ec2.AmazonLinuxGeneration.AMAZON_LINUX_2,
  };

  let ec2_config: EC2Config = {
    id,
    instanceType: ec2.InstanceType.of(
      ec2.InstanceClass.T3,
      ec2.InstanceSize.MEDIUM,
    ),
    machineImage: new ec2.AmazonLinuxImage(props),
    vpcSubnets: { subnetGroupName: SubnetNames.PublicSubnet },
    ssmSessionPermissions: true,
  };
  return ec2_config;
}
