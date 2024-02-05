import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as cdk from "aws-cdk-lib";
import * as eks from "aws-cdk-lib/aws-eks";
import { KubectlLayer } from "aws-cdk-lib/lambda-layer-kubectl";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import { Config } from "./config";
import { ElasticacheStack } from "./elasticache";
import { DataBaseConstruct } from "./rds";
import * as kms from "aws-cdk-lib/aws-kms";
import { readFileSync } from "fs";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import { Code, Function, Runtime } from "aws-cdk-lib/aws-lambda";
import { RetentionDays } from "aws-cdk-lib/aws-logs";

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
    locker: LockerSetup | undefined,
  ) {
    const cluster = new eks.Cluster(scope, "HSEKSCluster", {
      version: eks.KubernetesVersion.of("1.28"),
      kubectlLayer: new KubectlLayer(scope, "KubectlLayer"),
      defaultCapacity: 0,
      vpc: vpc,
      clusterName: "hs-eks-cluster",
    });

    const addClusterRole = (awsArn: string, name: string) => {
      if(!awsArn) return;
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
      "AWSXrayWriteOnlyAccess",
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

    nodegroupRole.attachInlinePolicy(cloudwatchPolicy);

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
                rust_locker_encryption_key: cdk.SecretValue.unsafePlainText("dummy_val"),
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
            logRetention: RetentionDays.INFINITE,
        });

    const triggerKMSEncryption = new cdk.CustomResource(
            scope,
            "HyperswitchKmsEncryptionCR",
            {
                serviceToken: kms_encrypt_function.functionArn,
            },
        );

    const kmsSecrets = new KmsSecrets(triggerKMSEncryption);

    // Create a security group for the load balancer
    const lbSecurityGroup = new ec2.SecurityGroup(scope, "HSLBSecurityGroup", {
      vpc: cluster.vpc,
      allowAllOutbound: false,
      securityGroupName: "hs-loadbalancer-sg",
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


    cluster.openIdConnectProvider.openIdConnectProviderIssuer;

    nodegroupRole.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonEBSCSIDriverPolicy'));
    cluster.addServiceAccount('EbsCsiControllerSa', {
      name: 'ebs-csi-controller-sa'+process.env.CDK_DEFAULT_REGION,
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
        clusterName: cluster.clusterName,
      },
    });

    const hypersChart = cluster.addHelmChart("HyperswitchServices", {
      chart: "hyperswitch-helm",
      repository: "https://juspay.github.io/hyperswitch-helm",
      namespace: "hyperswitch",
      release: "hypers-v1",
      wait: false,
      values: {
        clusterName: cluster.clusterName,
        services: {
            router: {
              image: "juspaydotin/hyperswitch-router:v1.105.0",
            },
            producer: {
              image: "juspaydotin/hyperswitch-producer:v1.105.0"
            },
            consumer: {
                image: "juspaydotin/hyperswitch-consumer:v1.105.0"
            }
        },
        application: {
          server: {
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
              kms_jwekey_vault_encryption_key: locker ? locker.locker_ec2.locker_pair.public_key : "locker-key",
              kms_jwekey_vault_private_key: locker ? locker.locker_ec2.tenant.private_key : "locker-key",
              kms_jwekey_tunnel_private_key: kmsSecrets.kms_jwekey_tunnel_private_key,
              kms_jwekey_rust_locker_encryption_key: kmsSecrets.kms_jwekey_rust_locker_encryption_key,
              kms_connector_onboarding_paypal_client_id: kmsSecrets.kms_connector_onboarding_paypal_client_id,
              kms_connector_onboarding_paypal_client_secret: kmsSecrets.kms_connector_onboarding_paypal_client_secret,
              kms_connector_onboarding_paypal_partner_id: kmsSecrets.kms_connector_onboarding_paypal_partner_id,
              kms_key_id: kmsSecrets.kms_id,
              kms_key_region: kmsSecrets.kms_region,
              kms_encrypted_api_hash_key: kmsSecrets.kms_encrypted_api_hash_key,
              admin_api_key: admin_api_key,
              jwt_secret: "test_admin",
              recon_admin_api_key: "test_admin",
            },
            master_enc_key: kmsSecrets.kms_encrypted_master_key,
            locker: {
              host: locker ? `http://${locker.locker_ec2.instance.instancePrivateIp}:8080` : "locker-host",
              locker_readonly_key: locker ? locker.locker_ec2.locker_pair.public_key : "locker-key",
              hyperswitch_private_key: locker ? locker.locker_ec2.tenant.private_key : "locker-key",
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
            image: "juspaydotin/hyperswitch-web:v1.0.4",
            env: {
              hyperswitchPublishableKey: "pk_test_123",
              hyperswitchSecretKey: "sk_test_123",
              hyperswitchServerUrl: "http://localhost:8080",
              hyperSwitchClientUrl: "http://localhost:8080",
            },
          },
        },

        postgresql: {
            enabled: false
        },
        externalPostgresql: {
            enabled: true,
            primary: {
                host: rds.db_cluster.clusterEndpoint.hostname,
                auth: {
                    username: "db_user",
                    database: "hyperswitch",
                    password: kmsSecrets.kms_encrypted_db_pass,
                },
            },
            replica: {
                host: rds.db_cluster.clusterReadEndpoint.hostname,
                auth: {
                    username: "db_user",
                    database: "hyperswitch",
                    password: kmsSecrets.kms_encrypted_db_pass,
                },

            }
        },
        loadBalancer: {
          targetSecurityGroup: lbSecurityGroup.securityGroupId,
        },
        redis: {
            enabled: false
        },
        externalRedis: {
          enabled: true,
          host: elasticache.cluster.attrRedisEndpointAddress || "redis",
          port: 6379
        },
        "hyperswitch-card-vault": {
          enabled: locker ? true : false,
          postgresql: {
            enabled: locker ? true : false,
          } 
        },
        "hyperswitchsdk": {
          enabled: true,
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
            }
          }
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
        promtail: {
          enabled: true,
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
          }
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
    readonly kms_jwt_secret: string;
    readonly kms_encrypted_db_pass: string;
    readonly kms_encrypted_master_key: string;
    readonly kms_id: string;
    readonly kms_region: string;
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
    readonly kms_encrypted_api_hash_key: string;

    constructor(kms: cdk.CustomResource) {
        this.kms_admin_api_key = kms.getAtt("admin_api_key").toString();
        this.kms_jwt_secret = kms.getAtt("jwt_secret").toString();
        this.kms_encrypted_db_pass = kms.getAtt("db_pass").toString();
        this.kms_encrypted_master_key = kms.getAtt("master_key").toString();
        this.kms_id = kms.getAtt("kms_id").toString();
        this.kms_region = kms.getAtt("kms_region").toString();
        this.kms_jwekey_locker_identifier1 = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_locker_identifier2 = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_locker_encryption_key1 = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_locker_encryption_key2 = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_locker_decryption_key1 = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_locker_decryption_key2 = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_vault_encryption_key = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_vault_private_key = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_tunnel_private_key = kms.getAtt("dummy_val").toString();
        this.kms_jwekey_rust_locker_encryption_key = kms.getAtt("dummy_val").toString();
        this.kms_connector_onboarding_paypal_client_id = kms.getAtt("dummy_val").toString();
        this.kms_connector_onboarding_paypal_client_secret = kms.getAtt("dummy_val").toString();
        this.kms_connector_onboarding_paypal_partner_id = kms.getAtt("dummy_val").toString();
        this.kms_encrypted_api_hash_key = kms.getAtt("api_hash_key").toString();
    }
}
