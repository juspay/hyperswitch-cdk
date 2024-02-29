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
import * as ssm from 'aws-cdk-lib/aws-ssm';
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { LockerSetup } from "./card-vault/components";
import { Trigger } from "aws-cdk-lib/triggers";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
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

    const ecr = new DockerImagesToEcr(scope);

    const cluster = new eks.Cluster(scope, "HSEKSCluster", {
      version: eks.KubernetesVersion.of("1.28"),
      kubectlLayer: new KubectlLayer(scope, "KubectlLayer"),
      defaultCapacity: 0,
      vpc: vpc,
      clusterName: "hs-eks-cluster",
    });

    cluster.node.addDependency(ecr.codebuildTrigger);

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
        new ec2.InstanceType("t3.medium"),
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
      logRetention: RetentionDays.INFINITE,
    });

    const triggerKMSEncryption = new cdk.CustomResource(
      scope,
      "HyperswitchKmsEncryptionCR",
      {
        serviceToken: kms_encrypt_function.functionArn,
      },
    );

    const kmsSecrets = new KmsSecrets(scope, triggerKMSEncryption);

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
            image: "juspaydotin/hyperswitch-router:v1.105.0-standalone",
          },
          producer: {
            image: "juspaydotin/hyperswitch-producer:v1.105.0-standalone"
          },
          consumer: {
            image: "juspaydotin/hyperswitch-consumer:v1.105.0-standalone"
          },
          controlCenter: {
            image: "juspaydotin/hyperswitch-control-center:v1.17.1"
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
              kms_jwekey_vault_encryption_key: locker?.locker_ec2.locker_pair.public_key || kmsSecrets.kms_jwekey_vault_encryption_key,
              kms_jwekey_vault_private_key: locker?.locker_ec2.tenant.private_key || kmsSecrets.kms_jwekey_vault_private_key,
              kms_jwekey_tunnel_private_key: kmsSecrets.kms_jwekey_tunnel_private_key,
              kms_jwekey_rust_locker_encryption_key: kmsSecrets.kms_jwekey_rust_locker_encryption_key,
              kms_connector_onboarding_paypal_client_id: kmsSecrets.kms_connector_onboarding_paypal_client_id,
              kms_connector_onboarding_paypal_client_secret: kmsSecrets.kms_connector_onboarding_paypal_client_secret,
              kms_connector_onboarding_paypal_partner_id: kmsSecrets.kms_connector_onboarding_paypal_partner_id,
              kms_key_id: kms_key.keyId,
              kms_key_region: kms_key.stack.region,
              kms_encrypted_api_hash_key: kmsSecrets.kms_encrypted_api_hash_key,
              admin_api_key: admin_api_key,
              jwt_secret: "test_admin",
              recon_admin_api_key: "test_admin",
            },
            // master_enc_key: kmsSecrets.kms_encrypted_master_key,
            locker: {
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
            host: rds.dbCluster?.clusterEndpoint.hostname,
            auth: {
              username: "db_user",
              database: "hyperswitch",
              password: config.rds.password,
              plainpassword: config.rds.password,
            },
          },
          readOnly: {
            host: rds.dbCluster?.clusterReadEndpoint.hostname,
            auth: {
              username: "db_user",
              database: "hyperswitch",
              password: config.rds.password,
              plainpassword: config.rds.password,
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
          },
          server: {
            secrets: {
              locker_private_key: locker?.locker_ec2.locker_pair.private_key || '',
              tenant_public_key: locker?.locker_ec2.tenant.public_key || '',
              master_key: locker ? config.locker.master_key : ""
            }
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
            forceBuild: true,
            gitCloneParam: {
              gitVersion: "0.16.7"
            },
            nginxConfig: { extraPath: "v0" }
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

  constructor(scope: Construct, kms: cdk.CustomResource) {

    let message = kms.getAtt("message");
    this.kms_admin_api_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/admin-api-key", 1);
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
    this.kms_encrypted_api_hash_key = ssm.StringParameter.valueForStringParameter(scope, "/hyperswitch/kms-encrypted-api-hash-key", 1);
  }
}

class DockerImagesToEcr {

  codebuildProject: codebuild.Project;
  codebuildTrigger: cdk.CustomResource;

  constructor(scope: Construct) {

    const ecrRole = new iam.Role(scope, "ECRRole", {
      assumedBy: new iam.ServicePrincipal("codebuild.amazonaws.com"),
    });

    const ecrPolicy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: [
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
    });

    this.codebuildTrigger = new cdk.CustomResource(scope, "ECRImageTransferCR", {
      serviceToken: triggerCodeBuild.functionArn,
    });
  }
}