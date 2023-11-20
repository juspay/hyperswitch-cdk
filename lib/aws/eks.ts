import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as cdk from "aws-cdk-lib";
import * as eks from "aws-cdk-lib/aws-eks";
import { KubectlLayer } from "aws-cdk-lib/lambda-layer-kubectl";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import { Config } from "./config";
import { ElasticacheStack } from "./elasticache";
import { DataBaseConstruct } from "./rds";
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';

export class EksStack {
  sg: ec2.ISecurityGroup;
  constructor(
    scope: Construct,
    config: Config,
    vpc: ec2.Vpc,
    rds: DataBaseConstruct,
    elasticache: ElasticacheStack,
    admin_api_key: string
  ) {
    const cluster = new eks.Cluster(scope, "HSEKSCluster", {
      version: eks.KubernetesVersion.of("1.28"),
      kubectlLayer: new KubectlLayer(scope, "KubectlLayer"),
      defaultCapacity: 0,
      vpc: vpc,
      clusterName: "hs-eks-cluster",
    });

    const awsArn = scope.node.tryGetContext("aws_arn");
    const isRole = awsArn.includes(":role") || awsArn.includes(":assumed-role");

    if (isRole) {
      const role = iam.Role.fromRoleName(
        scope,
        "AdminRole",
        awsArn.split("/")[1]
      );
      cluster.awsAuth.addRoleMapping(role, { groups: ["system:masters"] });
    } else {
      const user = iam.User.fromUserArn(scope, "User", awsArn);
      cluster.awsAuth.addUserMapping(user, { groups: ["system:masters"] });
    }

    const nodegroupRole = new iam.Role(scope, "HSNodegroupRole", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
    });

    // Attach the required policy to the nodegroup role
    const managedPolicies = [
      "AmazonEKSWorkerNodePolicy",
      "AmazonEKS_CNI_Policy",
      "AmazonEC2ContainerRegistryReadOnly",
    ];

    for (const policyName of managedPolicies) {
      nodegroupRole.addManagedPolicy(
        iam.ManagedPolicy.fromAwsManagedPolicyName(policyName)
      );
    }

    const fetchAndCreatePolicy = async (
      url: string
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
      "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.1/docs/install/iam_policy.json";

    fetchAndCreatePolicy(lbControllerPolicyUrl)
      .then((policy) => {
        nodegroupRole.attachInlinePolicy(
          new iam.Policy(scope, "HSAWSLoadBalancerControllerIAMPolicyInfo", {
            document: policy,
          })
        );

        nodegroupRole.attachInlinePolicy(
          new iam.Policy(
            scope,
            "HSAWSLoadBalancerControllerIAMInlinePolicyInfo",
            {
              document: new iam.PolicyDocument({
                statements: [
                  new iam.PolicyStatement({
                    actions: [
                      "elasticloadbalancing:AddTags",
                      "elasticloadbalancing:RemoveTags",
                    ],
                    effect: iam.Effect.ALLOW,
                    resources: [
                      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
                    ],
                  }),
                ],
              }),
            }
          )
        );
      })
      .catch((error) => {
        console.error("Error fetching or creating policy document:", error);
      });

    const nodegroup = cluster.addNodegroupCapacity("HSNodegroup", {
      nodegroupName: "hs-nodegroup",
      instanceTypes: [
        new ec2.InstanceType("t3.medium"),
        new ec2.InstanceType("t3a.medium"),
      ],
      minSize: 1,
      maxSize: 3,
      desiredSize: 2,
      labels: {
        "node-type": "generic-compute",
      },
      subnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      nodeRole: nodegroupRole,
    });

    const asg = cluster.addAutoScalingGroupCapacity("HSAutoScalingGroup", {
      instanceType: new ec2.InstanceType("t3.medium"),
      minCapacity: 1,
      maxCapacity: 3,
      desiredCapacity: 2,
      autoScalingGroupName: "generic-compute-asg",
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
    });

    // Create a security group for the load balancer
    const lbSecurityGroup = new ec2.SecurityGroup(scope, "HSLBSecurityGroup", {
      vpc: cluster.vpc,
      allowAllOutbound: false,
    });

    this.sg = cluster.clusterSecurityGroup;

    // Add inbound rule for all traffic
    lbSecurityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.allTraffic());

    // Add outbound rule to the EKS cluster
    lbSecurityGroup.addEgressRule(
      cluster.clusterSecurityGroup,
      ec2.Port.allTraffic()
    );

    cluster.clusterSecurityGroup.addIngressRule(
      lbSecurityGroup,
      ec2.Port.allTcp(),
      "Allow inbound traffic from an existing load balancer security group"
    );

    const albControllerChart = cluster.addHelmChart("ALBController", {
      createNamespace: false,
      wait: true,
      chart: "aws-load-balancer-controller",
      release: "hs-lb-v1",
      repository: "https://aws.github.io/eks-charts",
      namespace: "kube-system",
      values: {
        clusterName: cluster.clusterName,
      },
    });

    const hyperswitchServerLoadBalancer = new elbv2.ApplicationLoadBalancer(scope, 'HyperswitchServerLoadBalancer', {
      loadBalancerName: 'hyperswitch',
      vpc: vpc,
      securityGroup: lbSecurityGroup,
      internetFacing: true,
    });

    const hyperswitchLogsLoadBalancer = new elbv2.ApplicationLoadBalancer(scope, 'HyperswitchLogsLoadBalancer', {
      loadBalancerName: 'hyperswitch-logs',
      vpc: vpc,
      securityGroup: lbSecurityGroup,
      internetFacing: true,
    });

    new cdk.CfnOutput(scope, 'LoadBalancerHSDNS', {
      value: hyperswitchServerLoadBalancer.loadBalancerDnsName,
    });

    new cdk.CfnOutput(scope, 'LoadBalancerLogsDNS', {
      value: hyperswitchLogsLoadBalancer.loadBalancerDnsName,
    });

    const hyperswitchServerListener = hyperswitchServerLoadBalancer.addListener('HyperswitchServerListener', {
      port: 80,
      defaultAction: elbv2.ListenerAction.fixedResponse(404, {
        contentType: 'text/plain',
        messageBody: 'Not Found',
      }),
    });

    const hypersChart = cluster.addHelmChart("HyperswitchServices", {
      chart: "hyperswitch-helm",
      repository: "https://juspay.github.io/hyperswitch-helm",
      namespace: "hyperswitch",
      release: "hypers-v1",
      wait: true,
      values: {
        clusterName: cluster.clusterName,
        application: {
          server: {
            server_base_url: "https://sandbox.hyperswitch.io",
            secrets: {
              podAnnotations: {
                traffic_sidecar_istio_io_excludeOutboundIPRanges:
                  "10.23.6.12/32",
              },
              kms_admin_api_key: "test_admin",
              kms_jwt_secret: "test_admin",
              admin_api_key: admin_api_key,
              jwt_secret: "test_admin",
              recon_admin_api_key: "test_admin",
            },
            locker: {
              host: "locker-host",
            },
            basilisk: {
              host: "basilisk-host",
            },
          },
        },
        loadBalancer: {
          targetSecurityGroup: lbSecurityGroup.securityGroupId,
        },
        redis: {
          host: elasticache.cluster.attrRedisEndpointAddress || "redis",
          replicaCount: 1,
        },
        db: {
          host: rds.db_cluster.clusterEndpoint.hostname,
          name: "hyperswitch",
          user_name: "db_user",
          password: rds.password,
        },
        autoscaling: {
          enabled: true,
          minReplicas: 3,
          maxReplicas: 5,
          targetCPUUtilizationPercentage: 80,
        },
      },
    });

    hypersChart.node.addDependency(albControllerChart);

    hyperswitchServerListener.addAction('HyperswitchServerAction', {
      action: elbv2.ListenerAction.forward([new elbv2.ApplicationTargetGroup(scope, 'HyperswitchServerTargetGroup', {
        vpc: vpc,
        port: 8080,
        protocol: elbv2.ApplicationProtocol.HTTP,
        targets: [asg],
      })]),
      priority: 1,
      conditions: [
        elbv2.ListenerCondition.pathPatterns(['/*']),
      ],
    });

    const provider = cluster.openIdConnectProvider;

    const conditions = new cdk.CfnJson(scope, "ConditionJson", {
      value: {
        [`${provider.openIdConnectProviderIssuer}:aud`]: "sts.amazonaws.com",
        [`${provider.openIdConnectProviderIssuer}:sub`]:
          "system:serviceaccount:hyperswitch:loki-grafana",
      },
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
          "sts:AssumeRoleWithWebIdentity"
        ),
      }
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
      })
    );

    const lokiChart = cluster.addHelmChart("LokiController", {
      chart: "loki-stack",
      repository: "https://grafana.github.io/helm-charts/",
      namespace: "hyperswitch",
      release: "loki",
      values: {
        grafana: {
          image: {
            tag: "10.0.1",
          },
          enabled: true,
          adminPassword: "admin",
          serviceAccount: {
            annotations: {
              "eks.amazonaws.com/role-arn": grafanaServiceAccountRole.roleArn,
            },
          },
        },
      },
    });
    lokiChart.node.addDependency(hypersChart);

    cluster.addHelmChart("MetricsServer", {
      chart: "metrics-server",
      repository: "https://kubernetes-sigs.github.io/metrics-server/",
      namespace: "kube-system",
      release: "metrics-server",
    });

    // Output the cluster name and endpoint
    new cdk.CfnOutput(scope, "ClusterName", {
      value: cluster.clusterName,
    });

    new cdk.CfnOutput(scope, "ClusterEndpoint", {
      value: cluster.clusterEndpoint,
    });

    new cdk.CfnOutput(scope, "redisHost", {
      value: elasticache.cluster.attrRedisEndpointAddress,
    });

    new cdk.CfnOutput(scope, "dbHost", {
      value: rds.db_cluster.clusterEndpoint.hostname,
    });

    new cdk.CfnOutput(scope, "dbPassword", {
      value: rds.password,
    });

    new cdk.CfnOutput(scope, "lbSecurityGroupId", {
      value: lbSecurityGroup.securityGroupId,
    });
  }
}
