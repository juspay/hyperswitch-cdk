import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as autoscaling from 'aws-cdk-lib/aws-autoscaling';
import * as wafv2 from 'aws-cdk-lib/aws-wafv2';
import { Construct } from 'constructs';
import { readFileSync } from 'fs';
import { WAF } from './waf';
import * as eks from 'aws-cdk-lib/aws-eks';
import { IstioResources } from './istio_stack';
import { SecurityGroups } from './security_groups';

export interface AppProxiesConstructProps {
  vpc: ec2.IVpc; 
  cluster: eks.ICluster;
  securityGroups: SecurityGroups;
  istioInternalAlbDnsName: string;
  envoyAmiId?: string;
  squidAmiId?: string;
  s3VpcEndpointId: string;
}

export class AppProxiesConstruct extends Construct {
  public readonly envoyExternalAlbDns?: string;
  public readonly squidAlbDns?: string;
  public readonly envoyAsgSecurityGroup?: ec2.ISecurityGroup;

  constructor(scope: Construct, id: string, props: AppProxiesConstructProps) {
    super(scope, id);

    const vpc = props.vpc;
    const lbSecurityGroup = props.securityGroups.lbSecurityGroup;
    const cluster = props.cluster;
    
    // Get account and region from stack
    const stack = cdk.Stack.of(this);
    const account = stack.account;
    const region = stack.region;


    // --- Enhanced S3 VPC Endpoint Configuration ---
    
    const s3VpcEndpointId = props.s3VpcEndpointId;

    let s3VpcEndpoint = ec2.GatewayVpcEndpoint.fromGatewayVpcEndpointId(
      this, 
      'S3VpcEndpoint',
      s3VpcEndpointId 
    );

    // Get the subnets where instances will be deployed
    const envoyAsgSubnets = vpc.selectSubnets({ subnetGroupName: 'incoming-web-envoy-zone' });
    const squidAsgSubnets = vpc.selectSubnets({ subnetGroupName: 'outgoing-proxy-zone' });
    
    // For Gateway VPC Endpoints (like S3
    const allPrivateSubnets = [...envoyAsgSubnets.subnets, ...squidAsgSubnets.subnets];

    // Output route table information for debugging VPC endpoint connectivity
    const routeTableIds = new Set<string>();
    allPrivateSubnets.forEach((subnet) => {
      const routeTableId = subnet.routeTable.routeTableId;
      routeTableIds.add(routeTableId);
    });
    const vpcEndpointSg = props.securityGroups.vpcEndpointSecurityGroup;

    // Add ingress rules for all private subnet CIDRs to access VPC endpoints
    props.securityGroups.addVpcEndpointSubnetRules(allPrivateSubnets);

    // Use the Envoy ASG security group from centralized SecurityGroups
    const envoyAsgInstanceSg = props.securityGroups.envoyAsgSecurityGroup;
    
    const proxyConfigBucket = new s3.Bucket(this, "AppProxyConfigBucket", {
      bucketName: `app-proxy-config-${account}-${region}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
    });

    proxyConfigBucket.addToResourcePolicy(
      new iam.PolicyStatement({
        sid: 'AllowVpcEndpointAccess',
        effect: iam.Effect.ALLOW,
        principals: [new iam.AnyPrincipal()],
        actions: [
          's3:GetObject',
          's3:ListBucket',
          's3:GetBucketLocation'
        ],
        resources: [
          proxyConfigBucket.bucketArn,
          `${proxyConfigBucket.bucketArn}/*`
        ],
        conditions: {
          StringEquals: { 
            'aws:sourceVpc': vpc.vpcId
          }
        }
      })
    );

    proxyConfigBucket.addToResourcePolicy(
      new iam.PolicyStatement({
        sid: 'AllowCDKDeployment',
        effect: iam.Effect.ALLOW,
        principals: [new iam.AccountRootPrincipal()],
        actions: [
          's3:PutObject',
          's3:PutObjectAcl',
          's3:GetObject',
          's3:DeleteObject',
          's3:ListBucket'
        ],
        resources: [
          proxyConfigBucket.bucketArn,
          `${proxyConfigBucket.bucketArn}/*`
        ]
      })
    );

    // --- Envoy Proxy Setup ---
    if (props.envoyAmiId) {
      const envoyScope = new Construct(this, 'EnvoyProxy');

      // WAF for Envoy's external ALB
      const envoyWaf = new WAF(envoyScope, "EnvoyWAF");

      const externalAppLoadBalancer = new elbv2.ApplicationLoadBalancer(envoyScope, "EnvoyExternalAlb", {
        vpc: vpc,
        internetFacing: true,
        securityGroup: props.securityGroups.envoyExternalLbSecurityGroup!,
        loadBalancerName: "envoy-external-lb",
        vpcSubnets: { subnetGroupName: 'external-incoming-zone' }
      });

      new wafv2.CfnWebACLAssociation(envoyScope, 'EnvoyWebACLAssociation', {
        resourceArn: externalAppLoadBalancer.loadBalancerArn,
        webAclArn: envoyWaf.waf_arn,
      });
      externalAppLoadBalancer.node.addDependency(envoyWaf);

      let envoyConfigContent = readFileSync("lib/aws/configurations/envoy/envoy.yaml", "utf8")
        .replaceAll("{{external_loadbalancer_dns}}", externalAppLoadBalancer.loadBalancerDnsName)
        .replaceAll("{{internal_loadbalancer_dns}}", props.istioInternalAlbDnsName); 

      const envoyConfigDeployment = new s3deploy.BucketDeployment(envoyScope, "EnvoyConfigDeployment", {
        sources: [s3deploy.Source.data("envoy/envoy.yaml", envoyConfigContent)],
        destinationBucket: proxyConfigBucket,
      });
      envoyConfigDeployment.node.addDependency(externalAppLoadBalancer);


      let envoyUserdataContent = readFileSync("lib/aws/userdata/envoy_userdata.sh", "utf8")
        .replaceAll("{{bucket-name}}", proxyConfigBucket.bucketName);

      const envoyRole = new iam.Role(envoyScope, 'EnvoyInstanceRole', {
        assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
        managedPolicies: [
          iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
        ],
      });

      envoyRole.addToPolicy(new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          's3:GetObject',
          's3:ListBucket',
          's3:GetBucketLocation'
        ],
        resources: [
          proxyConfigBucket.bucketArn,
          `${proxyConfigBucket.bucketArn}/*`
        ]
      }));

      envoyRole.addToPolicy(new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'ssm:GetParameter',
          'ssm:GetParameters',
          'ssm:GetParametersByPath'
        ],
        resources: ['*']
      }));

      const envoyKeyPair = new ec2.KeyPair(envoyScope, 'EnvoyKeyPair', {
        keyPairName: `hyperswitch-envoy-proxy-keypair-${region}`,
        type: ec2.KeyPairType.RSA,
        format: ec2.KeyPairFormat.PEM,
      });

      const envoyLaunchTemplate = new ec2.LaunchTemplate(envoyScope, 'EnvoyLaunchTemplate', {
        machineImage: ec2.MachineImage.genericLinux({ [region]: props.envoyAmiId }),
        instanceType: new ec2.InstanceType("t3.medium"),
        securityGroup: envoyAsgInstanceSg, // Use the new dedicated SG for Envoy ASG instances
        keyPair: envoyKeyPair,
        userData: ec2.UserData.custom(envoyUserdataContent),
        role: envoyRole,
      });

      const envoyAsg = new autoscaling.AutoScalingGroup(envoyScope, 'EnvoyASG', {
        vpc: vpc,
        minCapacity: 1,
        maxCapacity: 2,
        launchTemplate: envoyLaunchTemplate,
        vpcSubnets: { subnetGroupName: 'incoming-web-envoy-zone' }
      });
      envoyAsg.node.addDependency(envoyConfigDeployment);

      const envoyListener = externalAppLoadBalancer.addListener('EnvoyListenerHttp', {
        port: 80,
        open: true,
        protocol: elbv2.ApplicationProtocol.HTTP,
      });

      envoyListener.addTargets('EnvoyTarget', {
        port: 80,
        protocol: elbv2.ApplicationProtocol.HTTP,
        targets: [envoyAsg],
        healthCheck: {
          path: "/healthz",  
          port: "80",
          protocol: elbv2.Protocol.HTTP,
          interval: cdk.Duration.seconds(30),
          timeout: cdk.Duration.seconds(5),
          healthyThresholdCount: 2,
          unhealthyThresholdCount: 2,
        }
      });

      this.envoyExternalAlbDns = externalAppLoadBalancer.loadBalancerDnsName;
      this.envoyAsgSecurityGroup = envoyAsgInstanceSg;
    }

    if (props.squidAmiId) {
      const squidScope = new Construct(this, 'SquidProxy');

      const squidLoadBalancer = new elbv2.ApplicationLoadBalancer(squidScope, "SquidAlb", {
        vpc: vpc,
        internetFacing: false,
        securityGroup: props.securityGroups.squidInternalLbSecurityGroup!,
        loadBalancerName: "squid-lb",
        vpcSubnets: { subnetGroupName: 'service-layer-zone' }
      });
      
      this.squidAlbDns = squidLoadBalancer.loadBalancerDnsName;

      const squidLogsBucket = new s3.Bucket(squidScope, "SquidLogsBucket", {
        bucketName: `squid-proxy-logs-${account}-${region}`,
        blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
        removalPolicy: cdk.RemovalPolicy.DESTROY,
        autoDeleteObjects: true, // For non-prod
        encryption: s3.BucketEncryption.S3_MANAGED,
      });

      const squidConfigDeployment = new s3deploy.BucketDeployment(squidScope, "SquidConfigDeployment", {
        sources: [s3deploy.Source.asset("lib/aws/configurations/squid")],
        destinationBucket: proxyConfigBucket,
        destinationKeyPrefix: "squid", 
      });

      let squidUserdataContent = readFileSync("lib/aws/userdata/squid_userdata.sh", "utf8") 
        .replaceAll("{{bucket-name}}", proxyConfigBucket.bucketName); 

      const squidRole = new iam.Role(squidScope, 'SquidInstanceRole', {
        assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
        managedPolicies: [
          iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
        ],
      });
      
      proxyConfigBucket.grantRead(squidRole);
      squidLogsBucket.grantReadWrite(squidRole);

      const squidKeyPair = new ec2.KeyPair(squidScope, 'SquidKeyPair', {
        keyPairName: `hyperswitch-squid-proxy-keypair-${region}`,
        type: ec2.KeyPairType.RSA,
        format: ec2.KeyPairFormat.PEM,
      });

      const squidLaunchTemplate = new ec2.LaunchTemplate(squidScope, 'SquidLaunchTemplate', {
        machineImage: ec2.MachineImage.genericLinux({ [region]: props.squidAmiId }),
        instanceType: new ec2.InstanceType("t3.medium"),
        securityGroup: props.securityGroups.squidAsgSecurityGroup!,
        keyPair: squidKeyPair,
        userData: ec2.UserData.custom(squidUserdataContent),
        role: squidRole,
      });

      const squidAsg = new autoscaling.AutoScalingGroup(squidScope, 'SquidASG', {
        vpc: vpc,
        minCapacity: 1, 
        maxCapacity: 2, 
        launchTemplate: squidLaunchTemplate,
        vpcSubnets: { subnetGroupName: 'outgoing-proxy-zone' }
      });
      squidAsg.node.addDependency(squidConfigDeployment);

      const squidListener = squidLoadBalancer.addListener('SquidListenerHttp', {
        port: 80,
        open: true,
        protocol: elbv2.ApplicationProtocol.HTTP,
      });

      squidListener.addTargets('SquidTarget', {
        port: 3128, 
        protocol: elbv2.ApplicationProtocol.HTTP,
        targets: [squidAsg],
        healthCheck: {
          path: "/squid-internal-mgr/health", 
          port: "3128",
          protocol: elbv2.Protocol.HTTP,
          interval: cdk.Duration.seconds(30),
          timeout: cdk.Duration.seconds(5),
          healthyThresholdCount: 2,
          unhealthyThresholdCount: 2,
        }
      });

    }
  }
}
