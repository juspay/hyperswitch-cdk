import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { Construct } from "constructs";
import { Config, EC2Config} from "./config";
import { Vpc, SubnetNames } from "./networking";
import { ElasticacheStack } from "./elasticache";
import { DataBaseConstruct } from "./rds";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import * as kms from "aws-cdk-lib/aws-kms";
import { readFileSync } from "fs";
import { EksStack } from "./eks";
import { SubnetStack } from "./subnet";
import { SecurityGroups } from "./security_groups";
import { EC2Instance } from "./ec2";
import { LockerSetup } from "./card-vault/components";
import * as iam from "aws-cdk-lib/aws-iam";
import { DatabaseInstance } from "aws-cdk-lib/aws-rds";
import { HyperswitchSDKStack } from "./hs-sdk";
import { DistributionConstruct } from './distribution';
import * as ssm from "aws-cdk-lib/aws-ssm";
import * as cloudfront from "aws-cdk-lib/aws-cloudfront";
import * as origins from "aws-cdk-lib/aws-cloudfront-origins";

export class AWSStack extends cdk.Stack {
  constructor(scope: Construct, config: Config) {
    super(scope, config.stack.name, {
      env: {
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: process.env.CDK_DEFAULT_REGION
      },
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

      if (rds.standaloneDb) {
        config = update_hosts_standalone(config, rds.standaloneDb.instanceEndpoint.hostname, elasticache.cluster.attrRedisEndpointAddress);
      }

      // Create SecurityGroups for standalone mode
      const securityGroups = new SecurityGroups(this, 'HyperswitchSecurityGroups', {
        vpc: vpc.vpc,
        isStandalone: true,
      });

      const ec2Sg = securityGroups.ec2SecurityGroup!;
      const appAlbSg = securityGroups.appAlbSecurityGroup!;

      const appAlb = new cdk.aws_elasticloadbalancingv2.ApplicationLoadBalancer(this, 'AppALB', {
        vpc: vpc.vpc,
        internetFacing: true,
        securityGroup: appAlbSg,
        vpcSubnets: { 
          subnetType: ec2.SubnetType.PUBLIC,
          onePerAz: true
        },
      });

      const sdkAlbSg = securityGroups.sdkAlbSecurityGroup!;

      const sdkAlb = new cdk.aws_elasticloadbalancingv2.ApplicationLoadBalancer(this, 'SdkALB', {
        vpc: vpc.vpc,
        internetFacing: true,
        securityGroup: sdkAlbSg,
        vpcSubnets: { 
          subnetType: ec2.SubnetType.PUBLIC,
          onePerAz: true
        },
      });

      config.hyperswitch_ec2.app_alb_dns = appAlb.loadBalancerDnsName;
      config.hyperswitch_ec2.sdk_alb_dns = sdkAlb.loadBalancerDnsName;

      const appAlb80Distribution = new cloudfront.Distribution(this, 'StandaloneDistribution', {
        defaultBehavior: {
          origin: new origins.HttpOrigin(appAlb.loadBalancerDnsName, {
            protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
          }),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.ALLOW_ALL,
          originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
        },
      });
      const appAlb9000Distribution = new cloudfront.Distribution(this, 'ControlCenterDistribution', {
        defaultBehavior: {
          origin: new origins.HttpOrigin(appAlb.loadBalancerDnsName, {
            protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
            httpPort: 9000,
          }),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.ALLOW_ALL,
          originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
        },
      });
      const sdkAlb9090Distribution = new cloudfront.Distribution(this, 'SdkAssetsDistribution', {
        defaultBehavior: {
          origin: new origins.HttpOrigin(sdkAlb.loadBalancerDnsName, {
            protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
            httpPort: 9090,
          }),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.ALLOW_ALL,
          originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
        },
      });
  
      const appCloudFrontUrl = appAlb80Distribution.distributionDomainName;
      const controlCenterCloudFrontUrl = appAlb9000Distribution.distributionDomainName;
      const sdkCloudFrontUrl = sdkAlb9090Distribution.distributionDomainName;

      const ec2Role = new iam.Role(this, 'HyperswitchEC2Role', {
        assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
        managedPolicies: [
          iam.ManagedPolicy.fromAwsManagedPolicyName('CloudWatchAgentServerPolicy'),
          iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMFullAccess')
        ]
      });

      ec2Role.addToPolicy(new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'ssm:UpdateInstanceInformation',
          'ssmmessages:CreateControlChannel',
          'ssmmessages:CreateDataChannel',
          'ssmmessages:OpenControlChannel',
          'ssmmessages:OpenDataChannel',
          'ec2messages:AcknowledgeMessage',
          'ec2messages:DeleteMessage',
          'ec2messages:FailMessage',
          'ec2messages:GetEndpoint',
          'ec2messages:GetMessages',
          'ec2messages:SendReply'
        ],
        resources: ['*']
      }));

      let hyperswitch_ec2 = new EC2Instance(
        this,
        vpc.vpc,
        {
          ...get_standalone_ec2_config(config, appCloudFrontUrl, sdkCloudFrontUrl),
          role: ec2Role
        }
      );
      
      rds.sg.addIngressRule(hyperswitch_ec2.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(hyperswitch_ec2.sg, ec2.Port.tcp(6379));
      hyperswitch_ec2.sg.addEgressRule(rds.sg, ec2.Port.tcp(5432));
      hyperswitch_ec2.sg.addEgressRule(elasticache.sg, ec2.Port.tcp(6379));
      hyperswitch_ec2.sg.addIngressRule(
        // To access the Router for User
        ec2.Peer.ipv4(vpc.vpc.vpcCidrBlock),
        ec2.Port.tcp(80),
      );
      hyperswitch_ec2.sg.addIngressRule(
        // To access the Control Center
        ec2.Peer.ipv4(vpc.vpc.vpcCidrBlock),
        ec2.Port.tcp(9000),
      );
      hyperswitch_ec2.sg.addIngressRule(
        // To access the SDK
        ec2.Peer.ipv4(vpc.vpc.vpcCidrBlock),
        ec2.Port.tcp(80),
      );
      hyperswitch_ec2.sg.addIngressRule(
        // To SSH into the instance
        ec2.Peer.ipv4(vpc.vpc.vpcCidrBlock),
        ec2.Port.tcp(22),
      );

      // Deploying SDK and Demo app in a single EC2 instance
      let hyperswitch_sdk_ec2 = new EC2Instance(
        this,
        vpc.vpc,
        {
          ...get_standalone_sdk_ec2_config(config, appCloudFrontUrl, sdkCloudFrontUrl),
          role: ec2Role
        }
      );

      // create an security group for the SDK and add rules to access the router and demo app with port 1234 after the hyperswitch_sdk_ec2 is created
      hyperswitch_sdk_ec2.sg.addIngressRule(
        // To access the SDK
        ec2.Peer.ipv4(vpc.vpc.vpcCidrBlock),
        ec2.Port.tcp(9090),
      );
      hyperswitch_sdk_ec2.sg.addIngressRule(
        // To Access Demo APP
        ec2.Peer.ipv4(vpc.vpc.vpcCidrBlock),
        ec2.Port.tcp(5252),
      );
      hyperswitch_sdk_ec2.sg.addIngressRule(
        // To SSH into the instance
        ec2.Peer.ipv4(vpc.vpc.vpcCidrBlock),
        ec2.Port.tcp(22),
      );

      let allowSdkToApplicationSg = new ec2.SecurityGroup(this, "allowSdkToApplicationSg", {
        vpc: vpc.vpc,
        securityGroupName: "allowSdkToApplicationSg",
        description: "Allow SDK to access the application", 
      });
 
      allowSdkToApplicationSg.addIngressRule(
        ec2.Peer.ipv4(hyperswitch_sdk_ec2.getInstance().instancePublicIp + "/0"),
        ec2.Port.tcp(80)
      );

      new ec2.CfnSecurityGroupIngress(this, 'AppAlbIngress', {
        groupId: hyperswitch_ec2.sg.securityGroupId,
        ipProtocol: 'tcp',
        fromPort: 80,
        toPort: 80,
        sourceSecurityGroupId: appAlbSg.securityGroupId,
      });

      new ec2.CfnSecurityGroupIngress(this, 'AppAlbIngress9000', {
        groupId: hyperswitch_ec2.sg.securityGroupId,
        ipProtocol: 'tcp',
        fromPort: 9000,
        toPort: 9000,
        sourceSecurityGroupId: appAlbSg.securityGroupId,
      });

      const listener80 = appAlb.addListener('Listener80', { port: 80, protocol: elbv2.ApplicationProtocol.HTTP });
      const target80 = new elbv2.ApplicationTargetGroup(this, 'AppTarget80', {
        vpc: vpc.vpc,
        port: 80,
        protocol: elbv2.ApplicationProtocol.HTTP,
        targetType: elbv2.TargetType.INSTANCE,
        targets: [hyperswitch_ec2],
        healthCheck: {
          path: '/health',
          protocol: elbv2.Protocol.HTTP,
          unhealthyThresholdCount: 10,
          healthyThresholdCount: 2,
          timeout: cdk.Duration.seconds(30),
          interval: cdk.Duration.seconds(60),
          healthyHttpCodes: '200-499'
        }
      });
      listener80.addTargetGroups('AppTargetGroup80', {
        targetGroups: [target80]
      });

      const listener9000 = appAlb.addListener('Listener9000', { port: 9000, protocol: elbv2.ApplicationProtocol.HTTP });
      listener9000.addTargets('AppTarget9000', {
        port: 9000,
        protocol: elbv2.ApplicationProtocol.HTTP,
        targets: [hyperswitch_ec2],
        healthCheck: { path: '/', protocol: elbv2.Protocol.HTTP }
      });

      const sdkListener9090 = sdkAlb.addListener('SdkListener9090', { port: 9090, protocol: elbv2.ApplicationProtocol.HTTP });
      sdkListener9090.addTargets('SdkTarget9090', {
        port: 9090,
        protocol: elbv2.ApplicationProtocol.HTTP,
        targets: [hyperswitch_sdk_ec2],
        healthCheck: { path: '/', protocol: elbv2.Protocol.HTTP }
      });

      const sdkListener5252 = sdkAlb.addListener('SdkListener5252', { port: 5252, protocol: elbv2.ApplicationProtocol.HTTP });
      sdkListener5252.addTargets('SdkTarget5252', {
        port: 5252,
        protocol: elbv2.ApplicationProtocol.HTTP,
        targets: [hyperswitch_sdk_ec2],
        healthCheck: { path: '/', protocol: elbv2.Protocol.HTTP }
      });

      new cdk.CfnOutput(this, "StandaloneURL", {
        value: `https://${appAlb80Distribution.distributionDomainName}/health`,
      });
      new cdk.CfnOutput(this, "ControlCenterURL", {
        value: `https://${appAlb9000Distribution.distributionDomainName}/`,
      });
      new cdk.CfnOutput(this, "SdkAssetsURL", {
        value: `https://${sdkAlb9090Distribution.distributionDomainName}/0.27.2/v0/HyperLoader.js`,
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
      // Get proxy configuration from context
      const appProxyEnabled = this.node.tryGetContext('app_proxy_enabled') === 'true';
      const envoyAmiId = this.node.tryGetContext('envoy_ami');
      const squidAmiId = this.node.tryGetContext('squid_ami');

      const securityGroups = new SecurityGroups(this, 'HyperswitchSecurityGroups', {
        vpc: vpc.vpc,
        isStandalone: false,
        appProxyEnabled: appProxyEnabled,
      });

      const s3VPCEndpoint = new ec2.GatewayVpcEndpoint(this, "S3VPCEndpoint", {
        vpc: vpc.vpc,
        service: ec2.GatewayVpcEndpointAwsService.S3,
        subnets: [ 
          { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
          { subnetType: ec2.SubnetType.PRIVATE_ISOLATED }
        ]
      });

      let eksStack = new EksStack( 
        this,
        config,
        vpc.vpc,
        rds,
        elasticache,
        config.hyperswitch_ec2.admin_api_key,
        locker,
        s3VPCEndpoint,
        securityGroups,
      );

        const controlCenterHost = this.node.tryGetContext("control_center_host");
        const appHost = this.node.tryGetContext("app_host");

        if (controlCenterHost && appHost) {
          const distribution = new DistributionConstruct(this, "CloudFrontDistributions", {
            controlCenterHost,
            appHost,
          });
          let hsSdk = new HyperswitchSDKStack(this, eksStack, distribution); 
        } else {
          console.warn("Skipping DistributionConstruct creation as context values are missing in stack.ts");
        }
      
    
      if (locker) locker.locker_ec2.addClient(eksStack.sg, ec2.Port.tcp(8080));
      rds.sg.addIngressRule(eksStack.sg, ec2.Port.tcp(5432));
      elasticache.sg.addIngressRule(eksStack.sg, ec2.Port.tcp(6379));

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
      internal_jump.addClient(external_jump.sg, ec2.Port.tcp(22));
      // internal_jump.addClient(rds.sg, ec2.Port.tcp(5432));
      rds.addClient(internal_jump.sg, 5432, "internal jump box");
      internal_jump.addClient(elasticache.sg, ec2.Port.tcp(6379));
      external_jump.sg.addIngressRule(external_jump.sg, ec2.Port.tcp(37689));

      const kms_key = new kms.Key(this, "hyperswitch-ssm-kms-key", {
        removalPolicy: cdk.RemovalPolicy.DESTROY,
        pendingWindow: cdk.Duration.days(7),
        keyUsage: kms.KeyUsage.ENCRYPT_DECRYPT,
        keySpec: kms.KeySpec.SYMMETRIC_DEFAULT,
        alias: "alias/hyperswitch-ssm-kms-key",
        description: "KMS key for encrypting the objects in an S3 bucket",
        enableKeyRotation: true,
      });

      const external_jump_role = external_jump.getInstance().role;
      const external_jump_policy = new iam.PolicyDocument({
        statements: [
          new iam.PolicyStatement({
            actions: [
              "ssmmessages:CreateControlChannel",
              "ssmmessages:CreateDataChannel",
              "ssmmessages:OpenControlChannel",
              "ssmmessages:OpenDataChannel",
              "ssm:UpdateInstanceInformation"
            ],
            resources: ["*"],
          }),
          new iam.PolicyStatement({
            actions: [
              "logs:CreateLogStream",
              "logs:PutLogEvents",
              "logs:DescribeLogGroups",
              "logs:DescribeLogStreams"
            ],
            resources: ["*"],
          }),
          new iam.PolicyStatement({
            actions: [
              "s3:GetEncryptionConfiguration"
            ],
            resources: ["*"],
          }),
          new iam.PolicyStatement({
            actions: [
              "kms:Decrypt"
            ],
            resources: [kms_key.keyArn],
          }),
          new iam.PolicyStatement({
            actions: [
              "kms:GenerateDataKey"
            ],
            resources: ["*"],
          }),

        ]
      });
      const ext_jump_policy = new iam.ManagedPolicy(this, 'SessionManagerPolicies', {
        managedPolicyName: `SessionManagerPolicies-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}`,
        description: "SessionManagerPolicies",
        document: external_jump_policy
      });

      ext_jump_policy.attachToRole(external_jump_role);

      const sgCfg = { "name": "vpce-sg", "description": "stack vpce sg" };

      const vpce_sg = new ec2.SecurityGroup(this, sgCfg.name, {
        vpc: vpc.vpc,
        description: sgCfg.description,
        allowAllOutbound: false,

      });

      vpce_sg.addIngressRule(ec2.Peer.ipv4("10.63.0.0/16"), ec2.Port.tcp(443));
      external_jump.sg.addEgressRule(vpce_sg, ec2.Port.tcp(443));

      const vpc_endpoint1 = new ec2.InterfaceVpcEndpoint(this, "SSMMessagesEP", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.SSM_MESSAGES,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "incoming-web-envoy-zone",
        },
      });
      const vpc_endpoint2 = new ec2.InterfaceVpcEndpoint(this, "IncomingWebServerSSMEP", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.SSM,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "incoming-web-envoy-zone",
        },
      });
      const vpc_endpoint3 = new ec2.InterfaceVpcEndpoint(this, "EC2MessagesEP", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.EC2_MESSAGES,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "incoming-web-envoy-zone",
        },
      });

      const vpc_endpoint4 = new ec2.InterfaceVpcEndpoint(this, "SecretsManagerEP", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.SECRETS_MANAGER,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "locker-database-zone",
        },
      });

      const kmsVPCEndpoint = new ec2.InterfaceVpcEndpoint(this, "KMSVPCEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.KMS,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "database-zone",
        }
      });

      const rdsEndpoint = new ec2.InterfaceVpcEndpoint(this, "RdsEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.RDS,
        subnets: {
          subnetGroupName: "database-zone"
        },
      });

      const ecrDkrEndpoint = new ec2.InterfaceVpcEndpoint(this, "ECRDkrEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.ECR_DOCKER,
        securityGroups: [vpce_sg],
        //needs hs-eks cluster sg (control plane sg)
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const logsEndpoint = new ec2.InterfaceVpcEndpoint(this, "LogsEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.CLOUDWATCH_LOGS, //check once
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const monitoringEndpoint = new ec2.InterfaceVpcEndpoint(this, "MonitoringEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.CLOUDWATCH_MONITORING, //check once
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const elasticloadbalancingEndpoint = new ec2.InterfaceVpcEndpoint(this, "ElasticLoadBalancingEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.ELASTIC_LOAD_BALANCING,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const ec2Endpoint = new ec2.InterfaceVpcEndpoint(this, "EC2Endpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.EC2,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const ecrApiEndpoint = new ec2.InterfaceVpcEndpoint(this, "ECRApiEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.ECR,
        securityGroups: [vpce_sg],
        //needs hs-eks cluster sg (control plane sg)
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const autoscalingEndpoint = new ec2.InterfaceVpcEndpoint(this, "AutoScalingEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.AUTOSCALING,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const stsEndpoint = new ec2.InterfaceVpcEndpoint(this, "STSEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.STS,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const snsEndpoint = new ec2.InterfaceVpcEndpoint(this, "SNSEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.SNS,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const xrayEndpoint = new ec2.InterfaceVpcEndpoint(this, "XRayEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.XRAY,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const lamdaEndpoint = new ec2.InterfaceVpcEndpoint(this, "LambdaEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.LAMBDA,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const elasticacheEndpoint = new ec2.InterfaceVpcEndpoint(this, "ElasticacheEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.ELASTICACHE,
        securityGroups: [vpce_sg],
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      const eksEndpoint = new ec2.InterfaceVpcEndpoint(this, "EksEndpoint", {
        vpc: vpc.vpc,
        service: ec2.InterfaceVpcEndpointAwsService.EKS,
        securityGroups: [vpce_sg],
        //needs hs-eks cluster sg (control plane sg)
        subnets: {
          subnetGroupName: "management-zone"
        },
      });

      // const executeApiEndpoint = new ec2.InterfaceVpcEndpoint(this, "ExecuteApiEndpoint", {
      //   vpc: vpc.vpc,
      //   service: ec2.InterfaceVpcEndpointAwsService.EXECUTE_API,
      //   securityGroups: [vpce_sg],
      //   subnets: {
      //     subnetGroupName: "management-zone"
      //   },
      // });

      if (locker)
        locker.locker_ec2.addClient(internal_jump.sg, ec2.Port.tcp(22));
      if (locker)
        locker.db_sg.addIngressRule(internal_jump.sg, ec2.Port.tcp(5432));
      if (locker)
        internal_jump.sg.addEgressRule(locker.db_sg, ec2.Port.tcp(5432));

      // rds.sg.addIngressRule(internal_jump.sg, ec2.Port.tcp(5432));
      // elasticache.sg.addIngressRule(internal_jump.sg, ec2.Port.tcp(6379));
    }
  }
}

function update_config(config: Config, db_host: string, redis_host: string) {
  config.hyperswitch_ec2.db_host = db_host;
  config.hyperswitch_ec2.redis_host = redis_host;
  return config;
}

function update_hosts_standalone(config: Config, db_host: string, redis_host: string) {
  config.hyperswitch_ec2.db_host = db_host;
  config.hyperswitch_ec2.redis_host = redis_host;
  return config;
}

function get_standalone_ec2_config(config: Config, appCloudFrontUrl?: string, sdkCloudFrontUrl?: string) {
  const appAlbDns = config.hyperswitch_ec2.app_alb_dns ?? "";
  let customData = readFileSync("lib/aws/userdata.sh", "utf8")
    .replaceAll("{{redis_host}}", config.hyperswitch_ec2.redis_host)
    .replaceAll("{{db_host}}", config.hyperswitch_ec2.db_host)
    .replaceAll("{{password}}", config.rds.password)
    .replaceAll("{{admin_api_key}}", config.hyperswitch_ec2.admin_api_key)
    .replaceAll("{{db_username}}", config.rds.db_user)
    .replaceAll("{{db_name}}", config.rds.db_name)
    .replaceAll("{{app_cloudfront_url}}", appCloudFrontUrl || "")
    .replaceAll("{{sdk_cloudfront_url}}", sdkCloudFrontUrl || "");
  let ec2_config: EC2Config = {
    id: "hyperswitch_standalone_app_cc_ec2",
    instanceType: ec2.InstanceType.of(
      ec2.InstanceClass.T2,
      ec2.InstanceSize.MICRO,
    ),
    machineImage: new ec2.AmazonLinuxImage(),
    vpcSubnets: { subnetGroupName: SubnetNames.PublicSubnet },
    userData: ec2.UserData.custom(customData),
    allowOutboundTraffic: true
  };
  return ec2_config;
}

function get_standalone_sdk_ec2_config(config: Config, appCloudFrontUrl?: string, sdkCloudFrontUrl?: string) {
  let customData = readFileSync("lib/aws/sdk_userdata.sh", "utf8")
    .replaceAll("{{admin_api_key}}", config.hyperswitch_ec2.admin_api_key)
    .replaceAll("{{version}}", "0.27.2")
    .replaceAll("{{sub_version}}", "v0")
    .replaceAll("{{app_cloudfront_url}}", appCloudFrontUrl || "")
    .replaceAll("{{sdk_cloudfront_url}}", sdkCloudFrontUrl || "");
  let ec2_config: EC2Config = {
    id: "hyperswitch_standalone_sdk_demo_ec2",
    instanceType: ec2.InstanceType.of(
      ec2.InstanceClass.T2,
      ec2.InstanceSize.MICRO,
    ),
    machineImage: new ec2.AmazonLinuxImage(),
    vpcSubnets: { subnetGroupName: SubnetNames.PublicSubnet },
    userData: ec2.UserData.custom(customData),
    allowOutboundTraffic: true,
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
    vpcSubnets: { subnetGroupName: "utils-zone" },
    associatePublicIpAddress: false,
    allowOutboundTraffic: false,
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
    vpcSubnets: { subnetGroupName: "management-zone" },
    ssmSessionPermissions: true,
    allowOutboundTraffic: false,
  };
  return ec2_config;
}
