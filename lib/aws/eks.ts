import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as cdk from "aws-cdk-lib";
import * as eks from "aws-cdk-lib/aws-eks";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import { Config } from "./config";
import fetch from "node-fetch";
import { ElasticacheStack } from "./elasticache";
import { DataBaseConstruct } from "./rds";

export class EksStack {
  sg: ec2.SecurityGroup;
  constructor(scope: Construct, config: Config, vpc: ec2.Vpc, rds: DataBaseConstruct, elasticache: ElasticacheStack ) {
    // Create the EKS cluster
    const cluster = new eks.Cluster(scope, "HSCluster", {
      version: eks.KubernetesVersion.of("1.28"),
      defaultCapacity: 0,
      vpc: vpc,
      clusterName: "hs-eks-cluster",
    });

    const role = iam.Role.fromRoleName(
      scope,
      "admin-role",
      "AWSReservedSSO_AWSAdministratorAccess_ebf3e1964512148f"
    );
    cluster.awsAuth.addRoleMapping(role, { groups: ["system:masters"] });

    const nodegroupRole = new iam.Role(scope, "HSNodegroupRole", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
    });

    // Attach the required policy to the nodegroup role
    nodegroupRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonEKSWorkerNodePolicy")
    );
    nodegroupRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonEKS_CNI_Policy")
    );
    nodegroupRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName(
        "AmazonEC2ContainerRegistryReadOnly"
      )
    );

    const fetchAndCreatePolicy = async (
      url: string
    ): Promise<iam.PolicyDocument> => {
      const response = await fetch(url);
      const policyJSON = await response.json();
      return iam.PolicyDocument.fromJson(policyJSON);
    };

    fetchAndCreatePolicy(
      "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.1/docs/install/iam_policy.json"
    )
      .then((policy) => {
        nodegroupRole.attachInlinePolicy(
          new iam.Policy(scope, "HSAWSLoadBalancerControllerIAMPolicyInfo", {
            document: policy,
          })
        );
        nodegroupRole.attachInlinePolicy(
          new iam.Policy(scope, "HSAWSLoadBalancerControllerIAMInlinePolicyInfo", {
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
          })
        );
      })
      .catch((error) => {
        console.error("Error fetching or creating policy document:", error);
      });

    // Create the node group in the EKS cluster
    const nodegroup = cluster.addNodegroupCapacity("HSNodegroup", {
      nodegroupName: "hs-nodegroup",
      instanceTypes: [new ec2.InstanceType("t3.medium")],
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

    this.sg = lbSecurityGroup;

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

    cluster.addHelmChart("ALBController", {
      createNamespace: false,
      chart: "aws-load-balancer-controller",
      release: "hs-lb-v1",
      repository: "https://aws.github.io/eks-charts",
      namespace: "kube-system",
      values: {
        clusterName: cluster.clusterName,
      },
    });

    cluster.addHelmChart("HyperswitchServices", {
      chart: "hyperswitch-helm",
      repository: "https://juspay.github.io/hyperswitch-helm",
      namespace: "hyperswitch",
      release: 'hypers-v1',
      values: {
        clusterName: cluster.clusterName,
        application: {
          server: {
            secrets: {
              kms_admin_api_key: "test_admin",
              kms_jwt_secret: "test_admin",
              admin_api_key: scope.node.tryGetContext('Please Enter Admin API key') || "test_admin",
              jwt_secret: "test_admin",
              recon_admin_api_key: "test_admin"
            },
            locker: {
              host: "locker-host"
            },
            basilisk: {
              host: "basilisk-host"
            }
          }
        },
        loadBalancer: {
          targetSecurityGroup: lbSecurityGroup.securityGroupId,
        },
        redis: {
          host: elasticache.cluster.attrRedisEndpointAddress || "redis",
          replicaCount: 1
        },
        db: {
          host: rds.db_cluster.clusterEndpoint.hostname,
          name: "hyperswitch",
          user_name: "db_user",
          password: rds.password,
        },
      },
    });

    cluster.addHelmChart("LokiController", {
      chart: "loki-stack",
      repository: "https://grafana.github.io/helm-charts/",
      namespace: "hyperswitch",
      release: 'hypers-lb-v1',
      values: {
        grafana: {
          enabled: true,
          adminPassword: "admin"
        }
      },
    });

    // Output the cluster name and endpoint
    new cdk.CfnOutput(scope, "ClusterName", {
      value: cluster.clusterName,
    });

    new cdk.CfnOutput(scope, "ClusterEndpoint", {
      value: cluster.clusterEndpoint,
    });
  }
}
