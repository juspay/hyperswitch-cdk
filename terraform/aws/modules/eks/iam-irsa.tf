# EKS Cluster Service Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.stack_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# EKS Cluster Policy
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_group" {
  name = "${var.stack_name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Node Group Required Policies
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_ec2_readonly_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_node_group.name
}

# Custom CloudWatch Policy for Node Groups
resource "aws_iam_role_policy" "eks_cloudwatch_custom" {
  name = "${var.stack_name}-eks-cloudwatch-policy"
  role = aws_iam_role.eks_node_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
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
        ]
        Resource = "*"
      }
    ]
  })
}

# ==========================================================
#                  OpenID Connect Provider
# ==========================================================

# OIDC Provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.common_tags
}

# ==========================================================
#            IAM Roles for Service Accounts (IRSA)
# ==========================================================

# Hyperswitch Router Service Account Role
resource "aws_iam_role" "hyperswitch_service_account" {
  name = "${var.stack_name}-hyperswitch-service-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:hyperswitch:hyperswitch-router-role"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# KMS and other policies for Hyperswitch
resource "aws_iam_role_policy" "hyperswitch_service_account_policy" {
  name = "${var.stack_name}-hyperswitch-service-account-policy"
  role = aws_iam_role.hyperswitch_service_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:*"]
        Resource = [var.kms_key_arn != null ? var.kms_key_arn : "*"]
      },
      {
        Sid    = "LoadBalancerAccess"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = ["*"]
      },
      {
        Sid      = "SSMAccess"
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = ["*"]
      },
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = ["*"]
      }
    ]
  })
}

# IAM Role for Istio Service Account
resource "aws_iam_role" "istio_service_account" {
  name = "${var.stack_name}-istio-service-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = [
              "system:serviceaccount:istio-system:istiod",
              "system:serviceaccount:istio-system:istio-ingressgateway"
            ]
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Istio service account policy
resource "aws_iam_role_policy" "istio_service_account_policy" {
  name = "${var.stack_name}-istio-service-account-policy"
  role = aws_iam_role.istio_service_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LoadBalancerRead"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Sid    = "ServiceDiscovery"
        Effect = "Allow"
        Action = [
          "servicediscovery:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for the Kubernetes ServiceAccount
resource "aws_iam_role" "grafana_service_account_role" {
  name = "grafana-service-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = [
              "system:serviceaccount:loki:loki-grafana",
              "system:serviceaccount:loki:loki"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "grafana_policy" {
  name = "grafana-inline-policy"
  role = aws_iam_role.grafana_service_account_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReadingMetricsFromCloudWatch",
        Effect = "Allow",
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowReadingLogsFromCloudWatch",
        Effect = "Allow",
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowReadingTagsInstancesRegionsFromEC2",
        Effect = "Allow",
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ],
        Resource = "*"
      },
      {
        Sid      = "AllowReadingResourcesForTags",
        Effect   = "Allow",
        Action   = "tag:GetResources",
        Resource = "*"
      }
    ]
  })
}

# IAM Role for EBS CSI Driver
# The EKS addon creates a service account named 'ebs-csi-controller-sa' in kube-system namespace
# This is the standard name used by the AWS EBS CSI Driver addon
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.stack_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# IAM Role for VPC CNI
resource "aws_iam_role" "vpc_cni_role" {
  name = "${var.stack_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni_role.name
}


# Module for AWS Load Balancer Controller IRSA
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.stack_name}-alb-controller-role"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.eks.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-sa"]
    }
  }
}

# Service accounts are now created in the helm module

