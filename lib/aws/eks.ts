import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as cdk from "aws-cdk-lib";
import * as eks from "aws-cdk-lib/aws-eks";
import { KubectlLayer } from "aws-cdk-lib/lambda-layer-kubectl";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import { Config } from "./config";
import { ElasticacheStack } from "./elasticache";
import { DataBaseConstruct } from "./rds";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { LockerSetup } from "./card-vault/components";
// import { LockerSetup } from "./card-vault/components";

export class EksStack {
  sg: ec2.ISecurityGroup;
  hyperswitchHost: string;
  lokiChart: eks.HelmChart;
  constructor(
    scope: Construct,
    config: Config,
    vpc: ec2.Vpc,
    rds: DataBaseConstruct,
    elasticache: ElasticacheStack,
    admin_api_key: string,
    locker: LockerSetup,
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
        awsArn.split("/")[1],
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
      "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.1/docs/install/iam_policy.json";

    fetchAndCreatePolicy(lbControllerPolicyUrl)
      .then((policy) => {
        nodegroupRole.attachInlinePolicy(
          new iam.Policy(scope, "HSAWSLoadBalancerControllerIAMPolicyInfo", {
            document: policy,
          }),
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
            },
          ),
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
      ec2.Port.allTraffic(),
    );

    cluster.clusterSecurityGroup.addIngressRule(
      lbSecurityGroup,
      ec2.Port.allTcp(),
      "Allow inbound traffic from an existing load balancer security group",
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
            image: "juspaydotin/hyperswitch-router:v1.78.0-standalone",
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
              host: "locker_host"
              // host: locker.locker_ec2.instance.instancePrivateIp,
              // locker_public_key: locker.locker_ec2.locker_pair.public_key,
              // hyperswitch_private_key:
              //   locker.locker_ec2.hyperswitch.private_key,
            },
            basilisk: {
              host: "basilisk-host",
            },
          },
          dashboard: {
            env: {
              apiBaseUrl: "http://localhost:8080",
              sdkBaseUrl: "http://localhost:8080",
            },
          },
          sdk: {
            image: "jeevaramachandran/hyperswitch-web:v1.0.0",
            env: {
              hyperswitchPublishableKey: "pk_test_123",
              hyperswitchSecretKey: "sk_test_123",
              hyperswitchServerUrl: "http://localhost:8080",
              hyperSwitchClientUrl: "http://localhost:8080",
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
    this.lokiChart = lokiChart;

    cluster.addHelmChart("MetricsServer", {
      chart: "metrics-server",
      repository: "https://kubernetes-sigs.github.io/metrics-server/",
      namespace: "kube-system",
      release: "metrics-server",
    });

    // // Import an existing load balancer by its ARN
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

    // Output the cluster name and endpoint
    new cdk.CfnOutput(scope, "ClusterName", {
      value: cluster.clusterName,
    });

    new cdk.CfnOutput(scope, "ClusterEndpoint", {
      value: cluster.clusterEndpoint,
    });

    new cdk.CfnOutput(scope, "RedisHost", {
      value: elasticache.cluster.attrRedisEndpointAddress,
    });

    new cdk.CfnOutput(scope, "DbHost", {
      value: rds.db_cluster.clusterEndpoint.hostname,
    });

    new cdk.CfnOutput(scope, "DbPassword", {
      value: rds.password,
    });

    new cdk.CfnOutput(scope, "LbSecurityGroupId", {
      value: lbSecurityGroup.securityGroupId,
    });
  }
}
