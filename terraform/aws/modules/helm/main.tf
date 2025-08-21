# AWS Current Region
data "aws_region" "current" {}

# AWS Account ID
data "aws_caller_identity" "current" {}

# ==========================================================
#                  Helm Provider Config
# ==========================================================

# Update kubeconfig to ensure kubectl and other tools work correctly
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${var.eks_cluster_name}"
  }

  triggers = {
    cluster_name = var.eks_cluster_name
  }
}

data "aws_eks_cluster_auth" "main" {
  name = var.eks_cluster_name

  depends_on = [null_resource.update_kubeconfig]
}

provider "kubernetes" {
  host                   = var.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(var.eks_cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes = {
    host                   = var.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(var.eks_cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# ==========================================================
#                    Kubernetes Service Accounts
# ==========================================================

# Service account for AWS Load Balancer Controller
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = var.alb_controller_role_arn
    }
  }
}

# Note: EBS CSI Driver service account is created by the EKS addon in the EKS module

# ==========================================================
#                       Helm Releases
# ==========================================================

# Helm release for AWS Load Balancer Controller
resource "helm_release" "alb_controller" {
  name       = "hs-lb-v1"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1" # Optional: pin chart version if you want
  wait       = true

  values = [
    yamlencode({
      clusterName = var.eks_cluster_name

      image = {
        repository = "${var.private_ecr_repository}/eks/aws-load-balancer-controller"
        tag        = "v2.12.0"
      }

      enableServiceMutatorWebhook = false
      region                      = data.aws_region.current.name
      vpcId                       = var.vpc_id

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.alb_controller.metadata[0].name
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.alb_controller
  ]
}

# Create namespace with Istio injection enabled
resource "kubernetes_namespace" "hyperswitch" {
  metadata {
    name = "hyperswitch"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

# Helm release for Istio base components
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = "istio-system"
  version          = "1.25.0"
  create_namespace = true
  wait             = true
  # Force replace CRDs on upgrade to avoid conflicts
  force_update = true
  values = [
    yamlencode({
      defaultRevision = "default"
      # Ensure CRDs are managed by this release
      base = {
        enableCRDTemplates = true
      }
    })
  ]
}

# Helm release for Istio control plane (istiod)
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"

  namespace  = "istio-system"
  version    = "1.25.0"
  wait       = true

  values = [
    yamlencode({
      global = {
        hub = "${var.private_ecr_repository}/istio"
        tag = "1.25.0"
        proxy = {
          # This ensures init containers can access external services
          holdApplicationUntilProxyStarts = true
        }
      }
      pilot = {
        nodeSelector = {
          "node-type" = "memory-optimized"
        }
        serviceAccount = {
          create = true
          name   = "istiod"
          annotations = {
            "eks.amazonaws.com/role-arn" = var.istio_service_account_role_arn
          }
        }
      }
      meshConfig = {
        defaultConfig = {
          # Ensures proxy starts before application containers
          holdApplicationUntilProxyStarts = true
        }
      }
    })
  ]

  depends_on = [
    helm_release.istio_base
  ]
}

# Helm release for Istio ingress gateway
resource "helm_release" "istio_gateway" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  version    = "1.25.0"
  wait       = true

  values = [
    yamlencode({
      global = {
        hub = "${var.private_ecr_repository}/istio"
        tag = "1.25.0"
      }
      service = {
        type = "ClusterIP"
      }
      nodeSelector = {
        "node-type" = "memory-optimized"
      }
      serviceAccount = {
        create = true
        name   = "istio-ingressgateway"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.istio_service_account_role_arn
        }
      }
    })
  ]

  depends_on = [
    helm_release.istiod
  ]
}

# Helm release for Hyperswitch Istio chart
resource "helm_release" "istio_services" {
  name       = "hs-istio"
  repository = "https://juspay.github.io/hyperswitch-helm/"
  chart      = "hyperswitch-istio"
  version    = "0.1.3"
  namespace  = "istio-system"

  create_namespace = true

  wait = true

  values = [
    yamlencode({
      # Namespace configuration
      namespace = "hyperswitch"

      # Service-specific versions
      hyperswitchServer = {
        version = "v1o116o0" # hyperswitch-router version
      }
      hyperswitchControlCenter = {
        version = "v1o37o3" # hyperswitch-control-center version
      }
      service = {
        type = "ClusterIP"
        port = 80
      }
      ingress = {
        enabled   = true
        className = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/backend-protocol"             = "HTTP"
          "alb.ingress.kubernetes.io/backend-protocol-version"     = "HTTP1"
          "alb.ingress.kubernetes.io/group.name"                   = "hyperswitch-istio-app-alb-ingress-group"
          "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "5"
          "alb.ingress.kubernetes.io/healthcheck-path"             = "/healthz/ready"
          "alb.ingress.kubernetes.io/healthcheck-port"             = "15021"
          "alb.ingress.kubernetes.io/healthcheck-protocol"         = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "2"
          "alb.ingress.kubernetes.io/healthy-threshold-count"      = "5"
          "alb.ingress.kubernetes.io/ip-address-type"              = "ipv4"
          "alb.ingress.kubernetes.io/listen-ports"                 = "[{\"HTTP\": 80}]"
          "alb.ingress.kubernetes.io/load-balancer-attributes"     = "routing.http.drop_invalid_header_fields.enabled=true,routing.http.xff_client_port.enabled=true,routing.http.preserve_host_header.enabled=true"
          "alb.ingress.kubernetes.io/scheme"                       = "internal"
          "alb.ingress.kubernetes.io/security-groups"              = aws_security_group.internal_alb_sg.id
          "alb.ingress.kubernetes.io/subnets"                      = join(",", var.subnet_ids["istio_lb_transit_zone"])
          "alb.ingress.kubernetes.io/target-type"                  = "ip"
          "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "3"
        }
        hosts = {
          paths = [
            {
              path     = "/"
              pathType = "Prefix"
              port     = 80
              name     = "istio-ingressgateway"
            },
            {
              path     = "/healthz/ready"
              pathType = "Prefix"
              port     = 15021
              name     = "istio-ingressgateway"
            }
          ]
        }
        tls = []
      }
      livenessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
      }
      readinessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
      }
      # Istio Base Configuration
      istio-base = {
        enabled = false
      }

      # Istiod Configuration
      istiod = {
        enabled = false
      }
      # Istio Gateway Configuration
      istio-gateway = {
        enabled = false
      }

      # Disable wait for crds job
      waitForCrds = {
        enabled = false
      }
    })
  ]

  depends_on = [
    helm_release.alb_controller,
    kubernetes_namespace.hyperswitch,
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.istio_gateway,
    aws_security_group.internal_alb_sg
  ]
}

# Helm release for Hyperswitch services
resource "helm_release" "hyperswitch_services" {
  name       = var.stack_name
  repository = "https://juspay.github.io/hyperswitch-helm/"
  chart      = "hyperswitch-stack"
  version    = "0.2.12"
  namespace  = "hyperswitch"

  wait = false

  values = [
    yamlencode({
      clusterName = var.eks_cluster_name

      prometheus = {
        enabled = false
      }

      alertmanager = {
        enabled = false
      }

      "hyperswitch-app" = {

        redis = {
          enabled = false
        }

        services = {
          router = {
            enabled = true
            image   = "${var.private_ecr_repository}/juspaydotin/hyperswitch-router:v1.116.0-standalone"
            version = "v1.116.0"
            host    = "https://${var.external_alb_distribution_domain_name}/api"
          }
          producer = {
            enabled = true
            image   = "${var.private_ecr_repository}/juspaydotin/hyperswitch-producer:v1.116.0-standalone"
            version = "v1.116.0"
          }
          consumer = {
            enabled = true
            image   = "${var.private_ecr_repository}/juspaydotin/hyperswitch-consumer:v1.116.0-standalone"
            version = "v1.116.0"
          }
          drainer = {
            enabled = true
            image   = "${var.private_ecr_repository}/juspaydotin/hyperswitch-drainer:v1.116.0-standalone"
            version = "v1.116.0"
          }
          controlCenter = {
            enabled = true
            image   = "${var.private_ecr_repository}/juspaydotin/hyperswitch-control-center:v1.37.3"
            version = "v1.37.3"
          }
          sdk = {
            host       = "https://${var.sdk_distribution_domain_name}"
            version    = var.sdk_version
            subversion = "v1"
          }
        }

        server = {
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [{
                  matchExpressions = [{
                    key      = "node-type"
                    operator = "In"
                    values   = ["generic-compute"]
                  }]
                }]
              }
            }
          }

          secrets_management = {
            secrets_manager = "aws_kms"
            aws_kms = {
              key_id = var.hyperswitch_kms_key_id
              region = data.aws_region.current.name
            }
          }

          region      = data.aws_region.current.name
          bucket_name = "logs-bucket-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

          serviceAccountAnnotations = {
            "eks.amazonaws.com/role-arn" = var.hyperswitch_service_account_role_arn
          }

          proxy = {
            enabled            = true
            http_url           = "http://${var.squid_nlb_dns_name}:3128"
            https_url          = "http://${var.squid_nlb_dns_name}:3128"
            bypass_proxy_hosts = "\"localhost,127.0.0.1,.svc,.svc.cluster.local,kubernetes.default.svc,169.254.169.254,.amazonaws.com,${var.rds_cluster_endpoint},${var.elasticache_cluster_endpoint_address},${var.external_alb_distribution_domain_name},${var.sdk_distribution_domain_name}\""
          }

          podAnnotations = {
            "traffic.sidecar.istio.io/excludeOutboundIPRanges" = "10.23.6.12/32"
          }

          secrets = {
            kms_admin_api_key                             = var.kms_secrets["kms_admin_api_key"]
            kms_jwt_secret                                = var.kms_secrets["kms_jwt_secret"]
            kms_jwekey_locker_identifier1                 = var.kms_secrets["kms_jwekey_locker_identifier1"]
            kms_jwekey_locker_identifier2                 = var.kms_secrets["kms_jwekey_locker_identifier2"]
            kms_jwekey_locker_encryption_key1             = var.kms_secrets["kms_jwekey_locker_encryption_key1"]
            kms_jwekey_locker_encryption_key2             = var.kms_secrets["kms_jwekey_locker_encryption_key2"]
            kms_jwekey_locker_decryption_key1             = var.kms_secrets["kms_jwekey_locker_decryption_key1"]
            kms_jwekey_locker_decryption_key2             = var.kms_secrets["kms_jwekey_locker_decryption_key2"]
            kms_jwekey_vault_encryption_key               = var.kms_secrets["kms_jwekey_vault_encryption_key"]
            kms_jwekey_vault_private_key                  = var.kms_secrets["kms_jwekey_vault_private_key"]
            kms_jwekey_tunnel_private_key                 = var.kms_secrets["kms_jwekey_tunnel_private_key"]
            kms_jwekey_rust_locker_encryption_key         = var.kms_secrets["kms_jwekey_rust_locker_encryption_key"]
            kms_connector_onboarding_paypal_client_id     = var.kms_secrets["kms_connector_onboarding_paypal_client_id"]
            kms_connector_onboarding_paypal_client_secret = var.kms_secrets["kms_connector_onboarding_paypal_client_secret"]
            kms_connector_onboarding_paypal_partner_id    = var.kms_secrets["kms_connector_onboarding_paypal_partner_id"]
            kms_key_id                                    = var.hyperswitch_kms_key_id
            kms_key_region                                = data.aws_region.current.name
            kms_encrypted_api_hash_key                    = var.kms_secrets["kms_encrypted_api_hash_key"]
            admin_api_key                                 = var.kms_secrets["kms_admin_api_key"]
            jwt_secret                                    = var.kms_secrets["kms_jwt_secret"]
            recon_admin_api_key                           = var.kms_secrets["kms_recon_admin_api_key"]
            forex_api_key                                 = var.kms_secrets["kms_forex_api_key"]
            forex_fallback_api_key                        = var.kms_secrets["kms_forex_fallback_api_key"]
            apple_pay_ppc                                 = var.kms_secrets["apple_pay_ppc"]
            apple_pay_ppc_key                             = var.kms_secrets["apple_pay_ppc_key"]
            apple_pay_merchant_cert                       = var.kms_secrets["apple_pay_merchant_conf_merchant_cert"]
            apple_pay_merchant_cert_key                   = var.kms_secrets["apple_pay_merchant_conf_merchant_cert_key"]
            apple_pay_merchant_conf_merchant_cert         = var.kms_secrets["apple_pay_merchant_conf_merchant_cert"]
            apple_pay_merchant_conf_merchant_cert_key     = var.kms_secrets["apple_pay_merchant_conf_merchant_cert_key"]
            apple_pay_merchant_conf_merchant_id           = var.kms_secrets["apple_pay_merchant_conf_merchant_id"]
            pm_auth_key                                   = var.kms_secrets["pm_auth_key"]
            api_hash_key                                  = var.kms_secrets["api_hash_key"]
            master_enc_key                                = var.kms_secrets["kms_encrypted_master_key"]
          }

          # Use KMS-encrypted placeholder values for network tokenization services
          google_pay_decrypt_keys = {
            google_pay_root_signing_keys = var.kms_secrets["google_pay_root_signing_keys"]
          }
          paze_decrypt_keys = {
            paze_private_key            = var.kms_secrets["paze_private_key"]
            paze_private_key_passphrase = var.kms_secrets["paze_private_key_passphrase"]
          }

          # Override network tokenization service with KMS-encrypted dummy values
          network_tokenization_service = {
            generate_token_url                 = "https://dummy.example.com/generate"
            fetch_token_url                   = "https://dummy.example.com/fetch"
            token_service_api_key             = var.kms_secrets["dummy_val"]
            public_key                        = var.kms_secrets["dummy_val"]
            private_key                       = var.kms_secrets["dummy_val"]
            key_id                           = "dummy_key_id"
            delete_token_url                 = "https://dummy.example.com/delete"
            check_token_status_url           = "https://dummy.example.com/status"
            webhook_source_verification_key  = var.kms_secrets["dummy_val"]
          }

          user_auth_methods = {
            encryption_key = var.kms_secrets["encryption_key"]
          }

          locker = {
            locker_enabled          = var.locker_enabled
            locker_public_key       = var.locker_enabled ? var.locker_public_key : "locker-key"
            hyperswitch_private_key = var.locker_enabled ? var.tenant_private_key : "locker-key"
          }

          basilisk = {
            host = "basilisk-host"
          }

          multitenancy = {
            tenants = {
              public = {
                base_url = "https://${var.external_alb_distribution_domain_name}/api"
                user={
                  control_center_url = "https://${var.external_alb_distribution_domain_name}"
                }
              }
            }
          }

          run_env = "sandbox"
        }

        consumer = {
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [{
                  matchExpressions = [{
                    key      = "node-type"
                    operator = "In"
                    values   = ["generic-compute"]
                  }]
                }]
              }
            }
          }
        }

        producer = {
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [{
                  matchExpressions = [{
                    key      = "node-type"
                    operator = "In"
                    values   = ["generic-compute"]
                  }]
                }]
              }
            }
          }
        }

        drainer = {
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [{
                  matchExpressions = [{
                    key      = "node-type"
                    operator = "In"
                    values   = ["generic-compute"]
                  }]
                }]
              }
            }
          }
        }

        controlCenter = {
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [{
                  matchExpressions = [{
                    key      = "node-type"
                    operator = "In"
                    values   = ["control-center"]
                  }]
                }]
              }
            }
          }
          env = {
            default__features__email = false
          }
        }

        postgresql = {
          enabled = false
        }

        externalPostgresql = {
          enabled = true
          primary = {
            host = var.rds_cluster_endpoint
            auth = {
              username      = "db_user"
              database      = "hyperswitch"
              password      = var.kms_secrets["kms_encrypted_db_pass"]
              plainpassword = var.db_password
            }
          }
          readOnly = {
            host = var.rds_cluster_reader_endpoint
            auth = {
              username      = "db_user"
              database      = "hyperswitch"
              password      = var.kms_secrets["kms_encrypted_db_pass"]
              plainpassword = var.db_password
            }
          }
        }

        externalRedis = {
          enabled = true
          host    = var.elasticache_cluster_endpoint_address
          port    = 6379
        }

        autoscaling = {
          enabled                        = true
          minReplicas                    = 3
          maxReplicas                    = 5
          targetCPUUtilizationPercentage = 80
        }

        analytics = {
          clickhouse = {
            enabled  = false
            password = "dummypassword"
          }
        }

        kafka = {
          enabled = false
        }

        clickhouse = {
          enabled = false
        }

        "hyperswitch-card-vault" = {
          enabled = false
          postgresql = {
            enabled = false
          }
        }
      }

      "hyperswitch-web" = {
        enabled = false
      }
    })
  ]

  depends_on = [
    helm_release.alb_controller,
    helm_release.istio_services,
    kubernetes_namespace.hyperswitch
  ]
}

# Istio Internal ALB Data Source
data "aws_lb" "internal_alb" {
  tags = {
    "ingress.k8s.aws/stack" = "hyperswitch-istio-app-alb-ingress-group" # Your group name
  }

  depends_on = [helm_release.istio_services]
}

resource "aws_s3_bucket" "loki_logs" {
  bucket = "${var.stack_name}-loki-logs-storage-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true

  tags = {
    Name = "${var.stack_name}-loki-logs-storage-bucket"
  }
}

resource "aws_s3_bucket_policy" "loki_logs_rw" {
  bucket = aws_s3_bucket.loki_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowGrafanaServiceAccountRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.grafana_service_account_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.loki_logs.arn,
          "${aws_s3_bucket.loki_logs.arn}/*"
        ]
      }
    ]
  })
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  chart      = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  namespace  = "kube-system"

  values = [
    yamlencode({
      image = {
        repository = "${var.private_ecr_repository}/bitnami/metrics-server"
        tag        = "0.7.2"
      }
    })
  ]
}
