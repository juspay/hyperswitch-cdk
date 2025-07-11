# AWS Current Region
data "aws_region" "current" {}

# ==========================================================
#                        EKS Cluster
# ==========================================================

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.stack_name}-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.control_plane_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = length(var.vpn_ips) > 0 ? var.vpn_ips : ["0.0.0.0/0"]
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-cluster"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.eks
  ]
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.stack_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

# ==========================================================
#                        EKS Addons
# ==========================================================

# EKS Addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni_role.arn

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-vpc-cni"
    }
  )
}


resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-kube-proxy"
    }
  )
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-coredns"
    }
  )

  depends_on = [
    aws_eks_node_group.hs_nodegroup
  ]
}

# EBS CSI Driver Addon
# This addon creates its own service account named 'ebs-csi-controller-sa' in kube-system namespace
# The IAM role trust policy in iam-irsa.tf is configured to trust this service account
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-ebs-csi-driver"
    }
  )

  depends_on = [
    aws_eks_node_group.hs_nodegroup,
  ]
}

# ==========================================================
#                       EKS Node Groups
# ==========================================================

resource "aws_eks_node_group" "hs_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "hs-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  labels = {
    "node-type" = "generic-compute"
  }

  tags = merge(var.common_tags, {
    Name = "hs-nodegroup"
  })
}

resource "aws_eks_node_group" "hs_autopilot_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "autopilot-od"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  labels = {
    "service" : "autopilot",
    "node-type" : "autopilot-od",
  }

  tags = merge(var.common_tags, {
    Name = "autopilot-od"
  })
}

resource "aws_eks_node_group" "hs_ckh_zookeeper_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "ckh-zookeeper-compute"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 3
    max_size     = 8
    min_size     = 3
  }

  labels = {
    "node-type" : "ckh-zookeeper-compute",
  }

  tags = merge(var.common_tags, {
    Name = "ckh-zookeeper-compute"
  })
}

resource "aws_eks_node_group" "hs_ckh_compute_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "clickhouse-compute-OD"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }

  labels = {
    "node-type" : "clickhouse-compute",
  }

  tags = merge(var.common_tags, {
    Name = "clickhouse-compute-OD"
  })
}

resource "aws_eks_node_group" "hs_control_center_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "control-center"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 1
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  labels = {
    "node-type" : "control-center",
  }

  tags = merge(var.common_tags, {
    Name = "control-center"
  })
}

resource "aws_eks_node_group" "hs_kafka_compute_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "kafka-compute-OD"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 3
  }

  labels = {
    "node-type" : "kafka-compute",
  }

  tags = merge(var.common_tags, {
    Name = "kafka-compute-OD"
  })
}

resource "aws_eks_node_group" "hs_memory_optimized_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "memory-optimized-od"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  labels = {
    "node-type" : "memory-optimized",
  }

  tags = merge(var.common_tags, {
    Name = "memory-optimized-od"
  })
}

resource "aws_eks_node_group" "hs_monitoring_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "monitoring-od"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 6
    max_size     = 63
    min_size     = 3
  }

  instance_types = ["t3.medium"]

  labels = {
    "node-type" : "monitoring",
  }

  tags = merge(var.common_tags, {
    Name = "monitoring-od"
  })
}

resource "aws_eks_node_group" "hs_pomerium_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "pomerium"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  instance_types = ["t3.medium"]

  labels = {
    "service" : "pomerium",
    "node-type" : "pomerium",
    "function" : "SSO",
  }

  tags = merge(var.common_tags, {
    Name = "pomerium"
  })
}

resource "aws_eks_node_group" "hs_system_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "system-nodes-od"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 1
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  labels = {
    "node-type" : "system-nodes",
  }

  tags = merge(var.common_tags, {
    Name = "system-nodes-od"
  })
}

resource "aws_eks_node_group" "hs_utils_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "utils-compute-od"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["utils_zone"]

  scaling_config {
    desired_size = 5
    max_size     = 8
    min_size     = 5
  }

  instance_types = ["t3.medium"]

  labels = {
    "node-type" : "elasticsearch",
  }

  tags = merge(var.common_tags, {
    Name = "utils-compute-od"
  })
}

resource "aws_eks_node_group" "hs_zk_compute_nodegroup" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "zookeeper-compute"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  subnet_ids = var.subnet_ids["eks_worker_nodes"]

  scaling_config {
    desired_size = 3
    max_size     = 10
    min_size     = 3
  }

  instance_types = ["t3.medium"]

  labels = {
    "node-type" : "zookeeper-compute",
  }

  tags = merge(var.common_tags, {
    Name = "zookeeper-compute"
  })
}
