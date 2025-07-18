import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as cdk from "aws-cdk-lib";
import * as eks from "aws-cdk-lib/aws-eks";
import { KubectlV32Layer } from '@aws-cdk/lambda-layer-kubectl-v32';
import * as cp from 'child_process'; 
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import { Config } from "./config";
import { ElasticacheStack } from "./elasticache";
import { DataBaseConstruct } from "./rds";
import { LogsStack } from "./log_stack";
import * as kms from "aws-cdk-lib/aws-kms";
import { readFileSync } from "fs";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import { Code, Function, Runtime } from "aws-cdk-lib/aws-lambda";
import { RetentionDays } from "aws-cdk-lib/aws-logs";
import * as ssm from 'aws-cdk-lib/aws-ssm';
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { LockerSetup } from "./card-vault/components";
import { Trigger } from "aws-cdk-lib/triggers";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment'; // Import the missing package
import { AutoScalingGroup } from "aws-cdk-lib/aws-autoscaling";
import { env } from "process";
import { WAF } from "./waf";
import { Keymanager } from "./keymanager/stack"
import * as wafv2 from 'aws-cdk-lib/aws-wafv2';
import { AppProxiesConstruct } from './app_proxies_construct';
import { IstioResources } from './istio_stack';
import { SecurityGroups } from './security_groups';
// import { LockerSetup } from "./card-vault/components";

export class EksStack {
  sg: ec2.ISecurityGroup;
  hyperswitchHost: string;
  lokiChart: eks.HelmChart;
  sdkBucket: s3.Bucket;
  sdkDistribution: cloudfront.CloudFrontWebDistribution;
  constructor(
    scope: Construct,
    config: Config,
    vpc: ec2.Vpc,
    rds: DataBaseConstruct,
    elasticache: ElasticacheStack,
    admin_api_key: string,
    locker: LockerSetup | undefined,
    s3VpcEndpoint: ec2.GatewayVpcEndpoint,
    securityGroups: SecurityGroups,
  ) {

    const ecrTransfer = new DockerImagesToEcr(scope, vpc);
    const privateEcrRepository = `${process.env.CDK_DEFAULT_ACCOUNT}.dkr.ecr.${process.env.CDK_DEFAULT_REGION}.amazonaws.com`

    let vpn_ips: string | string[] = scope.node.tryGetContext("vpn_ips") || [];

    if (typeof vpn_ips === "string") {
      vpn_ips = vpn_ips.split(",");
    }


    vpn_ips = vpn_ips.map((ip: string) => {
      if (ip === "0.0.0.0") {
        return ip + "/0";
      }
      return ip + "/32";
    });

    const cluster = new eks.Cluster(scope, "HSEKSCluster", {
      version: eks.KubernetesVersion.of("1.32"),
      kubectlLayer: new KubectlV32Layer(scope, "kubectlLayer"),
      defaultCapacity: 0,
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE.onlyFrom(...vpn_ips),
      vpc: vpc,
      clusterName: "hs-eks-cluster",
      securityGroup: securityGroups.clusterSecurityGroup,
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
        eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
        eks.ClusterLoggingTypes.SCHEDULER,
      ]
    });

    let push_logs = scope.node.tryGetContext('open_search_service') || 'n';
    if (`${push_logs}` == "y") {
      const logsStack = new LogsStack(scope, cluster, "app-logs-s3-service-account");
    }

    cluster.node.addDependency(ecrTransfer.codebuildTrigger);

    cdk.Tags.of(cluster).add("SubStack", "HyperswitchEKS");

    const addClusterRole = (awsArn: string, name: string) => {
      if (!awsArn) return;
      const isRole = awsArn.includes(":role") || awsArn.includes(":assumed-role");
      if (isRole) {
        const role = iam.Role.fromRoleName(
          scope,
          name,
          awsArn.split("/")[1],
        );
        cluster.awsAuth.addRoleMapping(role, { groups: ["system:masters"] });
      } else {
        const user = iam.User.fromUserArn(scope, name, awsArn);
        cluster.awsAuth.addUserMapping(user, { groups: ["system:masters"] });
      }
    }
    addClusterRole(scope.node.tryGetContext("aws_arn"), "AdminRole1");
    addClusterRole(scope.node.tryGetContext("additional_aws_arn"), "AdminRole2");

    const nodegroupRole = new iam.Role(scope, "HSNodegroupRole", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
    });

    // create a policy with complete access to cloudwatch metrics and logs
    const cloudwatchPolicy = new iam.Policy(scope, "HSCloudWatchPolicy", {
      statements: [
        new iam.PolicyStatement({
          actions: [
            "cloudwatch:DescribeAlarmsForMetric",
            "cloudwatch:DescribeAlarmHistory",
            "cloudwatch:DescribeAlarms",
            "cloudwatch:ListMetrics",
            "cloudwatch:GetMetricData",
            "cloudwatch:GetInsightRuleReport",
            "logs:DescribeLogGroups",
            "logs:GetLogGroupFields",
            "logs:StartQuery",
            "logs:StopQuery",
            "logs:GetQueryResults",
            "logs:GetLogEvents",
            "ec2:DescribeTags",
            "ec2:DescribeInstances",
            "ec2:DescribeRegions",
            "tag:GetResources",
          ],
          effect: iam.Effect.ALLOW,
          resources: ["*"],
        }),
      ],
    });

    const provider = cluster.openIdConnectProvider;

    const kmsConditions = new cdk.CfnJson(scope, "AppConditionJson", {
      value: {
        [`${provider.openIdConnectProviderIssuer}:aud`]: "sts.amazonaws.com",
        [`${provider.openIdConnectProviderIssuer}:sub`]:
          "system:serviceaccount:hyperswitch:hyperswitch-router-role",
      },
    });

    const hyperswitchServiceAccountRole = new iam.Role(
      scope,
      "HyperswitchServiceAccountRole",
      {
        assumedBy: new iam.FederatedPrincipal(
          provider.openIdConnectProviderArn,
          {
            StringEquals: kmsConditions,
          },
          "sts:AssumeRoleWithWebIdentity",
        ),
      },
    );

    // Create a KMS key
    const kms_key = new kms.Key(scope, "hyperswitch-kms-key", {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      pendingWindow: cdk.Duration.days(7),
      keyUsage: kms.KeyUsage.ENCRYPT_DECRYPT,
      keySpec: kms.KeySpec.SYMMETRIC_DEFAULT,
      alias: "alias/hyperswitch-kms-key",
      description: "KMS key for encrypting the objects in an S3 bucket",
      enableKeyRotation: false,
    });

    const kms_policy_document = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: ["kms:*"],
          resources: [kms_key.keyArn],
        }),
        new iam.PolicyStatement({
          actions: ["elasticloadbalancing:DeleteLoadBalancer",
            "elasticloadbalancing:DescribeLoadBalancers"],
          resources: ["*"],
        }),
        new iam.PolicyStatement({
          actions: ["ssm:*"],
          resources: ["*"],
        }),
        new iam.PolicyStatement({
          actions: ["secretsmanager:*"],
          resources: ["*"],
        }),
      ],
    });

    hyperswitchServiceAccountRole.attachInlinePolicy(
      new iam.Policy(scope, "HSAWSKMSKeyPolicy", {
        document: kms_policy_document,
      }),
    );

    // Attach the required policy to the nodegroup role
    const managedPolicies = [
      "AmazonEKSWorkerNodePolicy",
      "AmazonEKS_CNI_Policy",
      "AmazonEC2ContainerRegistryReadOnly",
      "CloudWatchAgentServerPolicy",
      "AmazonEC2ReadOnlyAccess",
    ];

    for (const policyName of managedPolicies) {
      nodegroupRole.addManagedPolicy(
        iam.ManagedPolicy.fromAwsManagedPolicyName(policyName),
      );
    }

    const fetchAndCreatePolicy = async (
      url: string,
    ): Promise<iam.PolicyDocument> => {
      try {
        const response = await fetch(url);
        const policyJSON = await response.json();
        return iam.PolicyDocument.fromJson(policyJSON);
      } catch (error) {
        console.error("Error fetching or creating policy document:", error);
        throw error;
      }
    };

    const lbControllerPolicyUrl =
      "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.12.0/docs/install/iam_policy.json";

    const albControllerServiceAccountName = "aws-load-balancer-controller-sa";
    const albControllerNamespace = "kube-system";
    const albControllerConditions = new cdk.CfnJson(scope, "ALBControllerConditionJson", {
      value: {
        [`${provider.openIdConnectProviderIssuer}:aud`]: "sts.amazonaws.com",
        [`${provider.openIdConnectProviderIssuer}:sub`]: `system:serviceaccount:${albControllerNamespace}:${albControllerServiceAccountName}`,
      },
    });
    const albControllerRole = new iam.Role(scope, "ALBControllerRole", {
      assumedBy: new iam.FederatedPrincipal(
        provider.openIdConnectProviderArn,
        { StringEquals: albControllerConditions },
        "sts:AssumeRoleWithWebIdentity"
      ),
    });
    
    fetchAndCreatePolicy(lbControllerPolicyUrl)
      .then((policy) => {
        albControllerRole.attachInlinePolicy(
          new iam.Policy(scope, "ALBControllerIAMPolicy", { document: policy })
        );
      })
      .catch((error) => {
        console.error("Error fetching or creating ALB controller policy document:", error);
      });

      const albControllerServiceAccount = cluster.addServiceAccount("ALBControllerSA", {
      name: albControllerServiceAccountName,
      namespace: albControllerNamespace,
      annotations: {
        "eks.amazonaws.com/role-arn": albControllerRole.roleArn,
      },
    });

    nodegroupRole.attachInlinePolicy(cloudwatchPolicy);

    const nodegroup = cluster.addNodegroupCapacity("HSNodegroup", {
      nodegroupName: "hs-nodegroup",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
        new ec2.InstanceType("t3.medium"),
      ],
      minSize: 1,
      maxSize: 3,
      desiredSize: 2,
      labels: {
        "node-type": "generic-compute",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,
    });

    const autopilotnodegroup = cluster.addNodegroupCapacity("HSAutopilotNodegroup", {
      nodegroupName: "autopilot-od",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
      ],
      minSize: 1,
      maxSize: 2,
      desiredSize: 1,
      labels: {
        "service": "autopilot",
        "node-type": "autopilot-od",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,

    });

    const ckhzookeepernodegroup = cluster.addNodegroupCapacity("HSCkhZookeeperNodegroup", {
      nodegroupName: "ckh-zookeeper-compute",
      minSize: 3,
      maxSize: 8,
      desiredSize: 3,
      labels: {
        "node-type": "ckh-zookeeper-compute",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,

    });

    const ckhcomputenodegroup = cluster.addNodegroupCapacity("HSCkhcomputeNodegroup", {
      nodegroupName: "clickhouse-compute-OD",
      minSize: 2,
      maxSize: 3,
      desiredSize: 2,
      labels: {
        "node-type": "clickhouse-compute",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,

    });

    const controlcenternodegroup = cluster.addNodegroupCapacity("HSControlcentreNodegroup", {
      nodegroupName: "control-center",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
      ],
      minSize: 1,
      maxSize: 5,
      desiredSize: 1,
      labels: {
        "node-type": "control-center",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,

    });

    const kafkacomputenodegroup = cluster.addNodegroupCapacity("HSKafkacomputeNodegroup", {
      nodegroupName: "kafka-compute-OD",
      minSize: 3,
      maxSize: 6,
      desiredSize: 3,
      labels: {
        "node-type": "kafka-compute",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,

    });

    const memoryoptimizenodegroup = cluster.addNodegroupCapacity("HSMemoryoptimizeNodegroup", {
      nodegroupName: "memory-optimized-od",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
      ],
      minSize: 1,
      maxSize: 5,
      desiredSize: 2,
      labels: {
        "node-type": "memory-optimized",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,
    });
    const monitoringnodegroup = cluster.addNodegroupCapacity("HSMonitoringNodegroup", {
      nodegroupName: "monitoring-od",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
      ],
      minSize: 3,
      maxSize: 63,
      desiredSize: 6,
      labels: {
        "node-type": "monitoring",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,

    });

    const pomeriumnodegroup = cluster.addNodegroupCapacity("HSPomeriumNodegroup", {
      nodegroupName: "pomerium",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
      ],
      minSize: 2,
      maxSize: 2,
      desiredSize: 2,
      labels: {
        "service": "pomerium",
        "node-type": "pomerium",
        "function": "SSO",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,

    });

    const systemnodegroup = cluster.addNodegroupCapacity("HSSystemNodegroup", {
      nodegroupName: "system-nodes-od",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
      ],
      minSize: 1,
      maxSize: 5,
      desiredSize: 1,
      labels: {
        "node-type": "system-nodes",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,

    });

    const utilsnodegroup = cluster.addNodegroupCapacity("HSUtilsNodegroup", {
      nodegroupName: "utils-compute-od",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
      ],
      minSize: 5,
      maxSize: 8,
      desiredSize: 5,
      labels: {
        "node-type": "elasticsearch",
      },
      subnets: { subnetGroupName: "utils-zone" },
      nodeRole: nodegroupRole,

    });

    const zookeepernodegroup = cluster.addNodegroupCapacity("HSZkcomputeNodegroup", {
      nodegroupName: "zookeeper-compute",
      minSize: 3,
      maxSize: 10,
      desiredSize: 3,
      labels: {
        "node-type": "zookeeper-compute",
      },
      subnets: { subnetGroupName: "eks-worker-nodes-one-zone" },
      nodeRole: nodegroupRole,
    });

    const lambda_role = new iam.Role(scope, "hyperswitch-lambda-role", {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
      inlinePolicies: {
        "use-kms-sm-s3": kms_policy_document,
      },
    });

    const encryption_code = readFileSync(
      "lib/aws/encryption.py",
    ).toString();

    let secret = new Secret(scope, "hyperswitch-kms-userdata-secret", {
      secretName: "HyperswitchKmsDataSecret",
      description: "KMS encryptable secrets for Hyperswitch",
      secretObjectValue: {
        db_password: cdk.SecretValue.unsafePlainText(
          rds.password,
        ),
        jwt_secret: cdk.SecretValue.unsafePlainText("test_admin"),
        master_key: cdk.SecretValue.unsafePlainText(config.hyperswitch_ec2.master_enc_key),
        admin_api_key: cdk.SecretValue.unsafePlainText(config.hyperswitch_ec2.admin_api_key),
        kms_id: cdk.SecretValue.unsafePlainText(kms_key.keyId),
        region: cdk.SecretValue.unsafePlainText(kms_key.stack.region),
        locker_public_key: cdk.SecretValue.unsafePlainText(locker ? locker.locker_ec2.locker_pair.public_key : "locker-key"),
        tenant_private_key: cdk.SecretValue.unsafePlainText(locker ? locker.locker_ec2.tenant.private_key : "locker-key")
      },
    });

    const kms_encrypt_function = new Function(scope, "hyperswitch-kms-encrypt", {
      functionName: "HyperswitchKmsEncryptionLambda",
      runtime: Runtime.PYTHON_3_9,
      handler: "index.lambda_handler",
      code: Code.fromInline(encryption_code),
      timeout: cdk.Duration.minutes(15),
      role: lambda_role,
      environment: {
        SECRET_MANAGER_ARN: secret.secretArn,
      },
    });

    const triggerKMSEncryption = new cdk.CustomResource(
      scope,
      "HyperswitchKmsEncryptionCR",
      {
        serviceToken: kms_encrypt_function.functionArn,
      },
    );

    const kmsSecrets = new KmsSecrets(scope, triggerKMSEncryption);

    // const delete_stack_code = readFileSync(
    //   "lib/aws/delete_stack.py",
    // ).toString();


    // const delete_stack_function = new Function(scope, "hyperswitch-stack-delete", {
    //   functionName: "HyperswitchStackDeletionLambda",
    //   runtime: Runtime.PYTHON_3_9,
    //   handler: "index.lambda_handler",
    //   code: Code.fromInline(delete_stack_code),
    //   timeout: cdk.Duration.minutes(15),
    //   role: lambda_role,
    //   environment: {
    //     SECRET_MANAGER_ARN: secret.secretArn,
    //   },
    // });

    // new cdk.CustomResource(
    //   scope,
    //   "HyperswitchStackDeletionCR",
    //   {
    //     serviceToken: delete_stack_function.functionArn,
    //   },
    // );

    // Use the load balancer security group from centralized SecurityGroups
    const lbSecurityGroup = securityGroups.lbSecurityGroup;

    this.sg = cluster.clusterSecurityGroup;

    const appProxyEnabled = scope.node.tryGetContext('app_proxy_enabled') === 'true';
    
    securityGroups.addEksClusterRules(securityGroups.clusterSecurityGroup, appProxyEnabled);
    securityGroups.addEksClusterRules(cluster.clusterSecurityGroup, appProxyEnabled);

    const albControllerChart = cluster.addHelmChart("ALBController", {
      createNamespace: false,
      wait: true,
      chart: "aws-load-balancer-controller",
      release: "hs-lb-v1",
      repository: "https://aws.github.io/eks-charts",
      namespace: "kube-system",
      values: {
        clusterName: cluster.clusterName,
        image: {
          repository: `${privateEcrRepository}/eks/aws-load-balancer-controller`,
          tag: "v2.12.0"
        },
        enableServiceMutatorWebhook: false,
        region: `${process.env.CDK_DEFAULT_REGION}`,
        vpcId: `${cluster.vpc.vpcId}`,
        serviceAccount: {
          create: false,
          name: albControllerServiceAccount.serviceAccountName,
        },
      },
    });
    albControllerChart.node.addDependency(albControllerServiceAccount);

    cluster.openIdConnectProvider.openIdConnectProviderIssuer;

    nodegroupRole.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonEBSCSIDriverPolicy'));
    cluster.addServiceAccount('EbsCsiControllerSa', {
      name: 'ebs-csi-controller-sa' + process.env.CDK_DEFAULT_REGION,
      namespace: 'kube-system',
      annotations: {
        'eks.amazonaws.com/role-arn': nodegroupRole.roleArn
      }
    });
    // Add EBS CSI driver
    const ebsCsiDriver = cluster.addHelmChart('EbsCsiDriver', {
      chart: 'aws-ebs-csi-driver',
      repository: 'https://kubernetes-sigs.github.io/aws-ebs-csi-driver',
      namespace: 'kube-system',
      values: {
        image: {
          repository: `${privateEcrRepository}/ebs-csi-driver/aws-ebs-csi-driver`,
          tag: 'v1.41.0'
        },
        sidecars: {
          provisioner: {
            image: {
              repository: `${privateEcrRepository}/eks-distro/kubernetes-csi/external-provisioner`,
              tag: 'v5.2.0-eks-1-32-10'
            }
          },
          attacher: {
            image: {
              repository: `${privateEcrRepository}/eks-distro/kubernetes-csi/external-attacher`,
              tag: 'v4.8.1-eks-1-32-10'
            }
          },
          snapshotter: {
            image: {
              repository: `${privateEcrRepository}/eks-distro/kubernetes-csi/external-snapshotter/csi-snapshotter`,
              tag: 'v8.2.1-eks-1-32-10'
            }
          },
          livenessProbe: {
            image: {
              repository: `${privateEcrRepository}/eks-distro/kubernetes-csi/livenessprobe`,
              tag: 'v2.15.0-eks-1-32-10'
            }
          },
          resizer: {
            image: {
              repository: `${privateEcrRepository}/eks-distro/kubernetes-csi/external-resizer`,
              tag: 'v1.13.2-eks-1-32-10'
            }
          },
          nodeDriverRegistrar: {
            image: {
              repository: `${privateEcrRepository}/eks-distro/kubernetes-csi/node-driver-registrar`,
              tag: 'v2.13.0-eks-1-32-10'
            }
          },
          volumemodifier: {
            image: {
              repository: `${privateEcrRepository}/ebs-csi-driver/volume-modifier-for-k8s`,
              tag: 'v0.5.1'
            }
          }
        }
      },
    });

    const sdkCorsRule: s3.CorsRule = {
      allowedOrigins: ["*"],
      allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.HEAD],
      allowedHeaders: ["*"],
      maxAge: 3000,
    }

    let sdkBucket = new s3.Bucket(scope, "HyperswitchSDKBucket", {
      bucketName: `hyperswitch-sdk-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}`,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: true,
      }),
      publicReadAccess: false,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      cors: [sdkCorsRule],
      autoDeleteObjects: true,
    });

    const oai = new cloudfront.OriginAccessIdentity(scope, 'SdkOAI');
    sdkBucket.grantRead(oai);
 
    this.sdkDistribution = new cloudfront.CloudFrontWebDistribution(scope, 'sdkDistribution', {
      viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.ALLOW_ALL,
      originConfigs: [
        {
          s3OriginSource: {
            s3BucketSource: sdkBucket,
            originAccessIdentity: oai,
          },
          behaviors: [{ isDefaultBehavior: true }, { pathPattern: '/*', allowedMethods: cloudfront.CloudFrontAllowedMethods.GET_HEAD }]
        }
      ]
    });
    
    this.sdkDistribution.node.addDependency(sdkBucket);
    new cdk.CfnOutput(scope, 'SdkDistribution', {
      value: this.sdkDistribution.distributionDomainName,
    });

    if (config.keymanager.enabled) {
      const km = new Keymanager(scope, config.keymanager, vpc, cluster, albControllerChart, nodegroupRole);
    }

    const sdk_version = "0.121.2";

    const hypersChart = cluster.addHelmChart("HyperswitchServices", {
      chart: "hyperswitch-stack",
      repository: "https://juspay.github.io/hyperswitch-helm/",
      version: "0.2.5",
      namespace: "hyperswitch",
      release: "hypers-v1",
      wait: false,
      values: {
        clusterName: cluster.clusterName,
        loadBalancer: {
          targetSecurityGroup: lbSecurityGroup.securityGroupId,
        },
        prometheus: {
          enabled: false
        },
        alertmanager: {
          enabled: false,
        },
        "hyperswitch-app": {
          loadBalancer: {
            targetSecurityGroup: lbSecurityGroup.securityGroupId
          },
          redis: {
            enabled: false
          },
          services: {
            router: {
              image: `${privateEcrRepository}/juspaydotin/hyperswitch-router:v1.114.0-standalone`,
            },
            producer: {
              image: `${privateEcrRepository}/juspaydotin/hyperswitch-producer:v1.114.0-standalone`
            },
            consumer: {
              image: `${privateEcrRepository}/juspaydotin/hyperswitch-consumer:v1.114.0-standalone`
            },
            controlCenter: {
              image: `${privateEcrRepository}/juspaydotin/hyperswitch-control-center:v1.37.1`
            },
            sdk: {
              host: "https://${this.sdkDistribution.distributionDomainName}",
              version: sdk_version,
              subversion: "v1"
            }
          },

          server: {
            nodeAffinity: {
              requiredDuringSchedulingIgnoredDuringExecution: {
                nodeSelectorTerms: [
                  {
                    matchExpressions: [
                      {
                        key: "node-type",
                        operator: "In",
                        values: ["generic-compute"]
                      }
                    ]
                  }
                ]
              }
            },
            secrets_management: {
              secrets_manager: "aws_kms",
              aws_kms: {
                key_id: kms_key.keyId,
                region: kms_key.stack.region
              }
            },
            region: `${process.env.CDK_DEFAULT_REGION}`,
            bucket_name: `logs-bucket-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}`,
            serviceAccountAnnotations: {
              "eks.amazonaws.com/role-arn": hyperswitchServiceAccountRole.roleArn,
            },
            server_base_url: "https://sandbox.hyperswitch.io",
            secrets: {
              podAnnotations: {
                traffic_sidecar_istio_io_excludeOutboundIPRanges:
                  "10.23.6.12/32",
              },
              kms_admin_api_key: kmsSecrets.kms_admin_api_key,
              kms_jwt_secret: kmsSecrets.kms_jwt_secret,
              kms_jwekey_locker_identifier1: kmsSecrets.kms_jwekey_locker_identifier1,
              kms_jwekey_locker_identifier2: kmsSecrets.kms_jwekey_locker_identifier2,
              kms_jwekey_locker_encryption_key1: kmsSecrets.kms_jwekey_locker_encryption_key1,
              kms_jwekey_locker_encryption_key2: kmsSecrets.kms_jwekey_locker_encryption_key2,
              kms_jwekey_locker_decryption_key1: kmsSecrets.kms_jwekey_locker_decryption_key1,
              kms_jwekey_locker_decryption_key2: kmsSecrets.kms_jwekey_locker_decryption_key2,
              kms_jwekey_vault_encryption_key: kmsSecrets.kms_jwekey_vault_encryption_key,
              kms_jwekey_vault_private_key: kmsSecrets.kms_jwekey_vault_private_key,
              kms_jwekey_tunnel_private_key: kmsSecrets.kms_jwekey_tunnel_private_key,
              kms_jwekey_rust_locker_encryption_key: kmsSecrets.kms_jwekey_rust_locker_encryption_key,
              kms_connector_onboarding_paypal_client_id: kmsSecrets.kms_connector_onboarding_paypal_client_id,
              kms_connector_onboarding_paypal_client_secret: kmsSecrets.kms_connector_onboarding_paypal_client_secret,
              kms_connector_onboarding_paypal_partner_id: kmsSecrets.kms_connector_onboarding_paypal_partner_id,
              kms_key_id: kms_key.keyId,
              kms_key_region: kms_key.stack.region,
              kms_encrypted_api_hash_key: kmsSecrets.kms_encrypted_api_hash_key,
              admin_api_key: kmsSecrets.kms_admin_api_key,
              jwt_secret: kmsSecrets.kms_jwt_secret,
              recon_admin_api_key: kmsSecrets.kms_recon_admin_api_key,
              forex_api_key: kmsSecrets.kms_forex_api_key,
              forex_fallback_api_key: kmsSecrets.kms_forex_fallback_api_key,
              apple_pay_ppc: kmsSecrets.apple_pay_ppc,
              apple_pay_ppc_key: kmsSecrets.apple_pay_ppc_key,
              apple_pay_merchant_cert: kmsSecrets.apple_pay_merchant_conf_merchant_cert,
              apple_pay_merchant_cert_key: kmsSecrets.apple_pay_merchant_conf_merchant_cert_key,
              apple_pay_merchant_conf_merchant_cert: kmsSecrets.apple_pay_merchant_conf_merchant_cert,
              apple_pay_merchant_conf_merchant_cert_key: kmsSecrets.apple_pay_merchant_conf_merchant_cert_key,
              apple_pay_merchant_conf_merchant_id: kmsSecrets.apple_pay_merchant_conf_merchant_id,
              pm_auth_key: kmsSecrets.pm_auth_key,
              api_hash_key: kmsSecrets.api_hash_key,
              master_enc_key: kmsSecrets.kms_encrypted_master_key,
            },
            google_pay_decrypt_keys: {
              google_pay_root_signing_keys:
                kmsSecrets.google_pay_root_signing_keys,
            },
            paze_decrypt_keys: {
              paze_private_key: kmsSecrets.paze_private_key,
              paze_private_key_passphrase: kmsSecrets.paze_private_key_passphrase,
            },
            user_auth_methods: {
              encryption_key: kmsSecrets.encryption_key,
            },
            locker: {
              locker_enabled: false,
              locker_public_key: locker ? locker.locker_ec2.locker_pair.public_key : "locker-key",
              hyperswitch_private_key: locker ? locker.locker_ec2.tenant.private_key : "locker-key",
            },
            basilisk: { 
              host: "basilisk-host",
            },
            run_env: "sandbox",
          },
          consumer: {
            nodeAffinity: {
              requiredDuringSchedulingIgnoredDuringExecution: {
                nodeSelectorTerms: [
                  {
                    matchExpressions: [
                      {
                        key: "node-type",
                        operator: "In",
                        values: ["generic-compute"]
                      }
                    ]
                  }
                ]
              }
            },
          },
          producer: {
            nodeAffinity: {
              requiredDuringSchedulingIgnoredDuringExecution: {
                nodeSelectorTerms: [
                  {
                    matchExpressions: [
                      {
                        key: "node-type",
                        operator: "In",
                        values: ["generic-compute"]
                      }
                    ]
                  }
                ]
              }
            },
          },
          controlCenter: {
            nodeAffinity: {
              requiredDuringSchedulingIgnoredDuringExecution: {
                nodeSelectorTerms: [
                  {
                    matchExpressions: [
                      {
                        key: "node-type",
                        operator: "In",
                        values: ["control-center"]
                      }
                    ]
                  }
                ]
              }
            },
            env: {
              default__features__email: false,
            }
          },
          postgresql: {
            enabled: false
          },
          externalPostgresql: {
            enabled: true,
            primary: {
              host: rds.dbCluster?.clusterEndpoint.hostname,
              auth: {
                username: "db_user",
                database: "hyperswitch",
                password: kmsSecrets.kms_encrypted_db_pass,
                plainpassword: config.rds.password,
              },
            },
            readOnly: {
              host: rds.dbCluster?.clusterReadEndpoint.hostname,
              auth: {
                username: "db_user",
                database: "hyperswitch",
                password: kmsSecrets.kms_encrypted_db_pass,
                plainpassword: config.rds.password,
              },
            }
          },
          externalRedis: {
            enabled: true,
            host: elasticache.cluster.attrRedisEndpointAddress || "redis",
            port: 6379
          },
          autoscaling: {
            enabled: true,
            minReplicas: 3,
            maxReplicas: 5,
            targetCPUUtilizationPercentage: 80,
          },
          analytics: {
            clickhouse: {
              enabled: false,
              password: "dummypassword"
            },
          },
          kafka: {
            enabled: false
          },
          clickhouse: {
            enabled: false,
          },
          "hyperswitch-card-vault": {
            enabled: false,
            postgresql: {
              enabled: false,
            },
            // server: {
            //   secrets: {
            //     locker_private_key: locker?.locker_ec2.locker_pair.private_key || '',
            //     tenant_public_key: locker?.locker_ec2.tenant.public_key || '',
            //     master_key: locker ? config.locker.master_key : ""
            //   }
            // }
          },
        },
        "hyperswitch-web": {
          enabled: true,
          services: {
            router: {
              host: "http://localhost:8080"
            },
            sdkDemo: {
              image: "juspaydotin/hyperswitch-web:v0.121.2",
              hyperswitchPublishableKey: "pub_key",
              hyperswitchSecretKey: "secret_key"
            }
          },
          loadBalancer: {
            targetSecurityGroup: lbSecurityGroup.securityGroupId
          },
          ingress: {
            className: "alb",
            annotations: {
              "alb.ingress.kubernetes.io/backend-protocol": "HTTP",
              "alb.ingress.kubernetes.io/backend-protocol-version": "HTTP1",
              "alb.ingress.kubernetes.io/group.name": "hyperswitch-web-alb-ingress-group",
              "alb.ingress.kubernetes.io/ip-address-type": "ipv4",
              "alb.ingress.kubernetes.io/listen-ports": '[{"HTTP": 80}]',
              "alb.ingress.kubernetes.io/load-balancer-name": "hyperswitch-web",
              "alb.ingress.kubernetes.io/scheme": "internet-facing",
              "alb.ingress.kubernetes.io/security-groups": lbSecurityGroup.securityGroupId,
              "alb.ingress.kubernetes.io/tags": "stack=hyperswitch-lb",
              "alb.ingress.kubernetes.io/target-type": "ip"
            },
            hosts: [{
              host: "",
              paths: [{
                path: "/",
                pathType: "Prefix"
              }
              ]
            }
            ]
          },
          autoBuild: {
            forceBuild: false,
            gitCloneParam: {
              gitVersion: sdk_version
            },
            buildParam: {
              envSdkUrl: `https://${this.sdkDistribution.distributionDomainName}`
            },
            nginxConfig: { extraPath: "v1" }
          }
        },
      },
    });

    this.sdkBucket = sdkBucket;
    hypersChart.node.addDependency(albControllerChart, triggerKMSEncryption); 

    if (appProxyEnabled) {
      const istioResources = new IstioResources(scope, 'IstioResources', {
        cluster: cluster,
        vpc: vpc,
        securityGroups: securityGroups,
      });
      istioResources.trafficControlChart.node.addDependency(hypersChart);

      const envoyAmiId = scope.node.tryGetContext('envoy_ami');
      const squidAmiId = scope.node.tryGetContext('squid_ami');
      
      if (envoyAmiId || squidAmiId) {
        // Create AppProxiesConstruct with centralized security groups
        const appProxiesConstruct = new AppProxiesConstruct(scope, 'AppProxies', {
          vpc: vpc,
          cluster: cluster,
          securityGroups: securityGroups,
          istioInternalAlbDnsName: istioResources.istioInternalAlbDnsName,
          envoyAmiId: envoyAmiId,
          squidAmiId: squidAmiId,
          s3VpcEndpointId: s3VpcEndpoint.vpcEndpointId,
        });

        appProxiesConstruct.node.addDependency(istioResources);
        
      }
    }

    // Add ingress rule from Istio Internal LB security group to EKS cluster security group
    cluster.clusterSecurityGroup.addIngressRule(
      securityGroups.istioInternalLbSecurityGroup,
      ec2.Port.tcp(80),
      "Allow HTTP traffic from Istio Internal LB security group",
    );

    const conditions = new cdk.CfnJson(scope, "ConditionJson", {
      value: {
        [`${provider.openIdConnectProviderIssuer}:aud`]: "sts.amazonaws.com",
        [`${provider.openIdConnectProviderIssuer}:sub`]:
          ["system:serviceaccount:loki:loki-grafana",
            "system:serviceaccount:loki:loki"
          ]
      },
    });

    const loki_s3 = new s3.Bucket(scope, "HyperswitchLokiBucket", {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      bucketName: `hs-loki-logs-storage-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}`,
    });


    const grafanaServiceAccountRole = new iam.Role(
      scope,
      "GrafanaServiceAccountRole",
      {
        assumedBy: new iam.FederatedPrincipal(
          provider.openIdConnectProviderArn,
          {
            StringEquals: conditions,
          },
          "sts:AssumeRoleWithWebIdentity",
        ),
      },
    );

    const grafanaPolicyDocument = iam.PolicyDocument.fromJson({
      Version: "2012-10-17",
      Statement: [
        {
          Sid: "AllowReadingMetricsFromCloudWatch",
          Effect: "Allow",
          Action: [
            "cloudwatch:DescribeAlarmsForMetric",
            "cloudwatch:DescribeAlarmHistory",
            "cloudwatch:DescribeAlarms",
            "cloudwatch:ListMetrics",
            "cloudwatch:GetMetricData",
            "cloudwatch:GetInsightRuleReport",
          ],
          Resource: "*",
        },
        {
          Sid: "AllowReadingLogsFromCloudWatch",
          Effect: "Allow",
          Action: [
            "logs:DescribeLogGroups",
            "logs:GetLogGroupFields",
            "logs:StartQuery",
            "logs:StopQuery",
            "logs:GetQueryResults",
            "logs:GetLogEvents",
          ],
          Resource: "*",
        },
        {
          Sid: "AllowReadingTagsInstancesRegionsFromEC2",
          Effect: "Allow",
          Action: [
            "ec2:DescribeTags",
            "ec2:DescribeInstances",
            "ec2:DescribeRegions",
          ],
          Resource: "*",
        },
        {
          Sid: "AllowReadingResourcesForTags",
          Effect: "Allow",
          Action: "tag:GetResources",
          Resource: "*",
        },
      ],
    });

    grafanaServiceAccountRole.attachInlinePolicy(
      new iam.Policy(scope, "GrafanaPolicy", {
        document: grafanaPolicyDocument,
      }),
    );

    // const loki_ns = cluster.addManifest("loki-ns", {
    //   "apiVersion": "v1",
    //   "kind": "Namespace",
    //   "metadata": {
    //     "name": "loki"
    //   }
    // });

    // const lokiSA = cluster.addServiceAccount("loki-sa", {
    //   namespace: "loki"
    // });
    // lokiSA.node.addDependency(loki_ns);
    loki_s3.grantReadWrite(grafanaServiceAccountRole);
    cluster.node.addDependency(loki_s3);

    // Use the Grafana security group from centralized SecurityGroups
    const grafana_ingress_lb_sg = securityGroups.grafanaIngressLbSecurityGroup;

    cluster.clusterSecurityGroup.addIngressRule(grafana_ingress_lb_sg, ec2.Port.tcp(3000));
    cluster.clusterSecurityGroup.addIngressRule(grafana_ingress_lb_sg, ec2.Port.tcp(80));

    // Add VPN-specific ingress rules if any VPN IPs are provided
    securityGroups.addGrafanaVpnRules(vpn_ips);

    const ext_incoming_zone_subnet = cluster.vpc.selectSubnets({
      subnetGroupName: "external-incoming-zone",
    });

    const lokiChart = cluster.addHelmChart("LokiController", {
      chart: "loki-stack",
      repository: "https://grafana.github.io/helm-charts/",
      namespace: "loki",
      release: "loki",
      values: {
        grafana: {
          global: {
            imageRegisrty: `${privateEcrRepository}`,
          },
          image: {
            repository: `${privateEcrRepository}/grafana/grafana`,
            tag: "latest",
          },
          sidecar: {
            image: {
              repository: `${privateEcrRepository}/kiwigrid/k8s-sidecar`,
              tag: "1.30.3",
              sha: ""
            },
            imagePullPolicy: "IfNotPresent",
            resources: {}
          },
          enabled: true,
          adminPassword: "admin",
          serviceAccount: {
            annotations: {
              "eks.amazonaws.com/role-arn": grafanaServiceAccountRole.roleArn,
            },
          },
          nodeSelector: {
            "node-type": "monitoring",
          },
          ingress: {
            enabled: true,
            ingressClassName: "alb",
            annotations: {
              "alb.ingress.kubernetes.io/backend-protocol": "HTTP",
              "alb.ingress.kubernetes.io/group.name": "hs-logs-alb-ingress-group",
              "alb.ingress.kubernetes.io/ip-address-type": "ipv4",
              "alb.ingress.kubernetes.io/healthcheck-path": "/api/health",
              "alb.ingress.kubernetes.io/listen-ports": '[{"HTTP": 80}]',
              "alb.ingress.kubernetes.io/load-balancer-attributes": "routing.http.drop_invalid_header_fields.enabled=true",
              "alb.ingress.kubernetes.io/load-balancer-name": "hyperswitch-grafana-logs",
              "alb.ingress.kubernetes.io/scheme": "internet-facing",
              "alb.ingress.kubernetes.io/tags": "stack=hyperswitch-lb",
              "alb.ingress.kubernetes.io/security-groups": grafana_ingress_lb_sg.securityGroupId,
              "alb.ingress.kubernetes.io/subnets": ext_incoming_zone_subnet.subnetIds.join(","),
              "alb.ingress.kubernetes.io/target-type": "ip"
            },
            extraPaths: [
              {
                path: "/",
                pathType: "Prefix",
                backend: {
                  service: {
                    name: "loki-grafana",
                    port: {
                      number: 80
                    }
                  }
                }
              }

            ],
            hosts: []

          }
        },
        loki: {
          enabled: true,
          global: {
            imageRegisrty: `${privateEcrRepository}`,
          },
          serviceAccount: {
            annotations: {
              "eks.amazonaws.com/role-arn": grafanaServiceAccountRole.roleArn,
            },
          },
          nodeSelector: {
            "node-type": "monitoring",
          },
          config: {
            limits_config: {
              enforce_metric_name: false,
              max_entries_limit_per_query: 5000,
              max_query_lookback: "90d",
              reject_old_samples: true,
              reject_old_samples_max_age: "168h",
              retention_period: "100d",
              retention_stream: [
                {
                  period: "7d",
                  priority: 1,
                  selector: '{level="debug"}'
                }
              ]
            },
            schema_config: {
              configs: [
                {
                  chunks: {
                    period: "24h",
                    prefix: "loki_chunk_",
                  },
                  from: "2024-05-01",
                  index: {
                    prefix: "loki_index_",
                    period: "24h",
                  },
                  object_store: "s3",
                  schema: "v12",
                  store: "tsdb"
                },
              ],
            },
            storage_config: {
              boltdb_shipper: {
                active_index_directory: "/data/loki/boltdb-shipper-active",
                cache_location: "/data/loki/boltdb-shipper-cache",
                cache_ttl: "24h",
                shared_store: "filesystem"
              },
              filesystem: {
                directory: "/data/loki/chunks"
              },
              hedging: {
                at: "250ms",
                max_per_second: 20,
                up_to: 3
              },
              tsdb_shipper: {
                active_index_directory: "/data/tsdb-index",
                cache_location: "/data/tsdb-cache",
                shared_store: "s3",
              },
              aws: {
                bucketnames: loki_s3.bucketName,
                region: `${process.env.CDK_DEFAULT_REGION}`
              }
            }
          },
          image: {
            repository: `${privateEcrRepository}/grafana/loki`,
            tag: "latest",
          },
        },
        promtail: {
          enabled: true,
          global: {
            imageRegisrty: `${privateEcrRepository}`,
          },
          image: {
            registry: `${privateEcrRepository}`,
            repository: "grafana/promtail",
            tag: "latest"
          },
          config: {
            snippets: {
              extraRelabelConfigs: [
                {
                  action: "keep",
                  regex: "hyperswitch-.*",
                  source_labels: ["__meta_kubernetes_pod_label_app"],
                },
              ],
            }
          },
        }
      },
    });


    lokiChart.node.addDependency(hypersChart);
    
    this.lokiChart = lokiChart;

    cluster.addHelmChart("MetricsServer", {
      chart: "metrics-server",
      repository: "https://kubernetes-sigs.github.io/metrics-server/",
      namespace: "kube-system",
      release: "metrics-server",
      values: {
        image: {
          repository: `${privateEcrRepository}/bitnami/metrics-server`,
          tag: "0.7.2",
        },
      }
    });

    // Import an existing load balancer by its ARN
    // const hypersLB = elbv2.ApplicationLoadBalancer.fromLookup(scope, 'HyperswitchLoadBalancer', {
    //   loadBalancerTags: { 'ingress.k8s.aws/stack': 'hyperswitch-alb-ingress-group' },
    // });
    // hypersLB.node.addDependency(lokiChart);

    // // Import an existing load balancer by its ARN
    // const hypersLogsLB = elbv2.ApplicationLoadBalancer.fromLookup(scope, 'HyperswitchLogsLoadBalancer', {
    //   loadBalancerTags: { 'ingress.k8s.aws/stack': 'hyperswitch-logs-alb-ingress-group' },
    // });
    // hypersLogsLB.node.addDependency(lokiChart);

    // // Import an existing load balancer by its ARN
    // const dashboardLB = elbv2.ApplicationLoadBalancer.fromLookup(scope, 'DashboardLoadBalancer', {
    //   loadBalancerTags: { 'ingress.k8s.aws/stack': 'hyperswitch-control-center-alb-ingress-group' },
    // });
    // dashboardLB.node.addDependency(lokiChart);

    // // Output the cluster name and endpoint
    // const hyperswitchHost = new cdk.CfnOutput(scope, "HyperswitchHost", {
    //   value: hypersLB.loadBalancerDnsName,
    // });

    // hyperswitchHost.node.addDependency(lokiChart);

    // this.hyperswitchHost = hypersLB.loadBalancerDnsName;

    // // Output the cluster name and endpoint
    // new cdk.CfnOutput(scope, "HyperswitchLogsHost", {
    //   value: hypersLogsLB.loadBalancerDnsName,
    // });
    // // Output the cluster name and endpoint
    // new cdk.CfnOutput(scope, "ControlCenterHost", {
    //   value: dashboardLB.loadBalancerDnsName,
    // });
  }
}

class KmsSecrets {
  readonly kms_admin_api_key: string;
  readonly kms_recon_admin_api_key: string;
  readonly kms_jwt_secret: string;
  readonly kms_encrypted_db_pass: string;
  readonly kms_encrypted_master_key: string;
  readonly kms_jwekey_locker_identifier1: string;
  readonly kms_jwekey_locker_identifier2: string;
  readonly kms_jwekey_locker_encryption_key1: string;
  readonly kms_jwekey_locker_encryption_key2: string;
  readonly kms_jwekey_locker_decryption_key1: string;
  readonly kms_jwekey_locker_decryption_key2: string;
  readonly kms_jwekey_vault_encryption_key: string;
  readonly kms_jwekey_vault_private_key: string;
  readonly kms_jwekey_tunnel_private_key: string;
  readonly kms_jwekey_rust_locker_encryption_key: string;
  readonly kms_connector_onboarding_paypal_client_id: string;
  readonly kms_connector_onboarding_paypal_client_secret: string;
  readonly kms_connector_onboarding_paypal_partner_id: string;
  readonly kms_forex_api_key: string;
  readonly kms_forex_fallback_api_key: string;
  readonly apple_pay_ppc: string;
  readonly apple_pay_ppc_key: string;
  readonly apple_pay_merchant_conf_merchant_cert: string;
  readonly apple_pay_merchant_conf_merchant_cert_key: string;
  readonly apple_pay_merchant_conf_merchant_id: string;
  readonly pm_auth_key: string;
  readonly api_hash_key: string;
  readonly kms_encrypted_api_hash_key: string;
  readonly encryption_key: string;
  readonly google_pay_root_signing_keys: string;
  readonly paze_private_key: string;
  readonly paze_private_key_passphrase: string;

  constructor(scope: Construct, kms: cdk.CustomResource) {

    let message = kms.getAtt("message");
    this.kms_admin_api_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/admin-api-key", 1);
    this.kms_recon_admin_api_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_jwt_secret = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/jwt-secret", 1);
    this.kms_encrypted_db_pass = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/db-pass", 1);
    this.kms_encrypted_master_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/master-key", 1);
    this.kms_jwekey_locker_identifier1 = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_jwekey_locker_identifier2 = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_jwekey_locker_encryption_key1 = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_jwekey_locker_encryption_key2 = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_jwekey_locker_decryption_key1 = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_jwekey_locker_decryption_key2 = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_jwekey_vault_encryption_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/locker-public-key", 1);
    this.kms_jwekey_vault_private_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/tenant-private-key", 1);
    this.kms_jwekey_tunnel_private_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_jwekey_rust_locker_encryption_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_connector_onboarding_paypal_client_id = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_connector_onboarding_paypal_client_secret = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_connector_onboarding_paypal_partner_id = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_forex_api_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.kms_forex_fallback_api_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.apple_pay_ppc = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.apple_pay_ppc_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.apple_pay_merchant_conf_merchant_cert = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.apple_pay_merchant_conf_merchant_cert_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.apple_pay_merchant_conf_merchant_id = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.pm_auth_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.api_hash_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/kms-encrypted-api-hash-key", 1);
    this.kms_encrypted_api_hash_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/kms-encrypted-api-hash-key", 1);
    this.encryption_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/dummy-val", 1);
    this.google_pay_root_signing_keys = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/google-pay-root-signing-keys", 1);
    this.paze_private_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/paze-private-key", 1);
    this.paze_private_key_passphrase = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/paze-private-key-passphrase", 1);
  }
}

class DockerImagesToEcr {

  codebuildProject: codebuild.Project;
  codebuildTrigger: cdk.CustomResource;

  constructor(scope: Construct, vpc: ec2.Vpc) {

    const ecrRole = new iam.Role(scope, "ECRRole", {
      assumedBy: new iam.ServicePrincipal("codebuild.amazonaws.com"),
    });

    const ecrPolicy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: [
            "ecr:CreateRepository",
            "ecr:CompleteLayerUpload",
            "ecr:GetAuthorizationToken",
            "ecr:UploadLayerPart",
            "ecr:InitiateLayerUpload",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage",
          ],
          resources: ["*"],
        }),
      ]
    });

    ecrRole.attachInlinePolicy(
      new iam.Policy(scope, "ECRFullAccessPolicy", {
        document: ecrPolicy,
      }),
    );

    this.codebuildProject = new codebuild.Project(scope, "ECRImageTransfer", {
      environmentVariables: {
        AWS_ACCOUNT_ID: {
          value: process.env.CDK_DEFAULT_ACCOUNT,
        },
        AWS_DEFAULT_REGION: {
          value: process.env.CDK_DEFAULT_REGION,
        },
      },
      environment: {
        buildImage: codebuild.LinuxBuildImage.AMAZON_LINUX_2_5,
      },
      role: ecrRole,
      buildSpec: codebuild.BuildSpec.fromAsset("./dependencies/code_builder/buildspec.yml"),
    });

    const lambdaStartBuildCode = readFileSync('./dependencies/code_builder/start_build.py').toString();

    const triggerCodeBuildRole = new iam.Role(scope, "ECRImageTransferLambdaRole", {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
    });

    const triggerCodeBuildPolicy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: [
            "codebuild:StartBuild",
          ],
          resources: [this.codebuildProject.projectArn],
        }),
      ]
    });

    const logsPolicy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ],
          resources: ["*"],
        })
      ]
    })

    triggerCodeBuildRole.attachInlinePolicy(
      new iam.Policy(scope, "ECRImageTransferLambdaPolicy", {
        document: triggerCodeBuildPolicy,
      }),
    );

    triggerCodeBuildRole.addToPolicy(
      new iam.PolicyStatement({
        actions: [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface",
          "secretsmanager:GetSecretValue",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:PutObject"
        ],
        resources: ["*"],
      })
    );

    triggerCodeBuildRole.attachInlinePolicy(
      new iam.Policy(scope, "ECRImageTransferLambdaLogsPolicy", {
        document: logsPolicy,
      }),
    );

    const triggerCodeBuild = new Function(scope, "ECRImageTransferLambda", {
      runtime: Runtime.PYTHON_3_9,
      handler: "index.lambda_handler",
      code: Code.fromInline(lambdaStartBuildCode),
      timeout: cdk.Duration.minutes(15),
      role: triggerCodeBuildRole,
      environment: {
        PROJECT_NAME: this.codebuildProject.projectName,
      },
      vpc: vpc,
      vpcSubnets: {
        subnetGroupName: "isolated-subnet-1"
      }
    });

    this.codebuildTrigger = new cdk.CustomResource(scope, "ECRImageTransferCR", {
      serviceToken: triggerCodeBuild.functionArn,
    });
  }
}
