# ==========================================================
#                  Helm Configurations
# ==========================================================


# Update kubeconfig to ensure kubectl and other tools work correctly
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.gke_cluster_name} --region=${var.region} --project=${var.project_id}"
  }

  triggers = {
    cluster_name = var.gke_cluster_name
  }
}


data "google_client_config" "current" {}

data "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.region
  project  = var.project_id
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}

provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.primary.endpoint}"
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
    token                  = data.google_client_config.current.access_token
  }
}

# ==========================================================
#              Service Account Configurations
# ==========================================================

# Google Service Accounts for Istio
resource "google_service_account" "hyperswitch_istio_gsa" {
  account_id   = "hyperswitch-istio-gsa"
  display_name = "Istio GSA for Workload Identity"
}

# Grant the Workload Identity User role to the GSA for multiple KSAs.
resource "google_service_account_iam_binding" "istio_workload_identity" {
  service_account_id = google_service_account.istio_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[istio-system/istiod]",
    "serviceAccount:${var.project_id}.svc.id.goog[istio-system/istio-ingressgateway]"
  ]
}

# Grant the GSA permissions required by Istio.
resource "google_project_iam_member" "istio_load_balancer_read" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.istio_gsa.email}"
}

resource "google_project_iam_member" "istio_service_discovery" {
  project = var.project_id
  role    = "roles/servicedirectory.editor"
  member  = "serviceAccount:${google_service_account.istio_gsa.email}"
}

# For Cloud Logging access (like CloudWatch logs)
resource "google_project_iam_member" "istio_cloud_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.istio_gsa.email}"
}

# Google Service Account for Hyperswitch
resource "google_service_account" "hyperswitch_gsa" {
  account_id   = "hyperswitch-gsa"
  display_name = "Hyperswitch GSA for Workload Identity"
}

# Grant the Workload Identity User role to the GSA
# This is the equivalent of the AWS assume_role_policy.
resource "google_service_account_iam_member" "hyperswitch_workload_identity" {
  service_account_id = google_service_account.hyperswitch_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[hyperswitch/hyperswitch-router-role]"
}

# Grant the GSA permissions to access GCP services.
resource "google_project_iam_member" "hyperswitch_kms_access" {
  project = var.project_id
  role    = "roles/cloudkms.admin"
  member  = "serviceAccount:${google_service_account.hyperswitch_gsa.email}"
}

resource "google_project_iam_member" "hyperswitch_load_balancer_access" {
  project = var.project_id
  role    = "roles/compute.loadBalancerAdmin"
  member  = "serviceAccount:${google_service_account.hyperswitch_gsa.email}"
}

resource "google_project_iam_member" "hyperswitch_ssm_access" {
  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${google_service_account.hyperswitch_gsa.email}"
}

# ==========================================================
#                       Helm Releases
# ==========================================================

# Helm release for Istio services
resource "helm_release" "istio_services" {
  name       = var.stack_name
  repository = "https://juspay.github.io/hyperswitch-helm/"
  chart      = "hyperswitch-istio"
  version    = "0.1.2"
  namespace  = "istio-system"

  wait = true

  values = [
    yamlencode({
      # Default values for hyperswitch-istio.

      # Namespace configuration
      namespace = "hyperswitch"

      # Service-specific versions
      hyperswitchServer = {
        version = "v1o116o0"
      }

      hyperswitchControlCenter = {
        version = "v1o37o3"
      }

      service = {
        type = "ClusterIP"
        port = 80
      }



      ingress = {
        enabled   = true
        className = "gce"
        annotations = {
          # This is the GCP ingress class name.
          "kubernetes.io/ingress.class" = "gce"
          # This annotation creates an internal L7 Load Balancer, equivalent to `alb.ingress.kubernetes.io/scheme: internal`.
          "networking.gke.io/internal-load-balancer-type" = "global"
          # The `GCE` Ingress controller's health checks are configured in a single JSON block.
          # This is the equivalent of all the `alb.ingress.kubernetes.io/healthcheck-*` annotations.
          "ingress.gcp.kubernetes.io/backend-service-healthcheck" = "{\"healthCheck\": {\"requestPath\": \"/healthz/ready\", \"port\": 15021, \"protocol\": \"HTTP\", \"checkIntervalSec\": 5, \"timeoutSec\": 2, \"healthyThreshold\": 5, \"unhealthyThreshold\": 3}}"
          # GCP handles IP address type automatically based on the network configuration.
          # The GCLB operates within the GKE cluster's VPC, so there's no direct equivalent for `subnets` or `security-groups` annotations.
          # Security is managed via VPC Firewall Rules.
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
        enabled         = true
        defaultRevision = "default"
        # Ensure CRDs are managed by this release
        base = {
          enableCRDTemplates = true
        }
      }

      # Istiod Configuration
      istiod = {
        enabled = true

        global = {
          # hub = "${var.private_ecr_repository}/istio"
          # tag = "1.25.0"
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
              "iam.gke.io/gcp-service-account" = google_service_account.hyperswitch_istio_gsa.email
            }
          }
        }
        meshConfig = {
          defaultConfig = {
            # Ensures proxy starts before application containers
            holdApplicationUntilProxyStarts = true
          }
        }
      }

      # Istio Gateway Configuration
      istio-gateway = {
        enabled = true
        global = {
          # hub = "${var.private_ecr_repository}/istio"
          # tag = "1.25.0"
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
            "iam.gke.io/gcp-service-account" = google_service_account.hyperswitch_istio_gsa.email
          }
        }
      }
    })
  ]

  depends_on = [
    null_resource.update_kubeconfig,
    google_service_account.hyperswitch_istio_gsa,
    google_service_account_iam_binding.istio_workload_identity,
    google_project_iam_member.istio_load_balancer_read,
    google_project_iam_member.istio_service_discovery,
    google_project_iam_member.istio_cloud_logging
  ]

}

# Create namespace with optional Istio injection
resource "kubernetes_namespace" "hyperswitch" {
  metadata {
    name = var.hyperswitch_namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

# Helm release for Hyperswitch services
resource "helm_release" "hyperswitch_services" {
  name       = var.stack_name
  repository = "https://juspay.github.io/hyperswitch-helm/"
  chart      = "hyperswitch-stack"
  version    = "0.2.12"
  namespace  = var.hyperswitch_namespace

  wait = false

  values = [
    yamlencode({
      "hyperswitch-app" = {

        services = {
          router = {
            enabled = true
            image   = "docker.juspay.io/juspaydotin/hyperswitch-router:v1.116.0" # "${var.private_ecr_repository}/juspaydotin/hyperswitch-router:v1.116.0"
            version = "v1.116.0"
            host    = "https://${var.app_cdn_domain_name}/api"
          }
          producer = {
            enabled = true
            image   = "docker.juspay.io/juspaydotin/hyperswitch-producer:v1.116.0" # "${var.private_ecr_repository}/juspaydotin/hyperswitch-producer:v1.114.0-standalone"
            version = "v1.116.0"
          }
          consumer = {
            enabled = true
            image   = "docker.juspay.io/juspaydotin/hyperswitch-consumer:v1.116.0" # "${var.private_ecr_repository}/juspaydotin/hyperswitch-consumer:v1.114.0-standalone"
            version = "v1.116.0"
          }
          drainer = {
            enabled = true
            image   = "docker.juspay.io/juspaydotin/hyperswitch-drainer:v1.116.0" # "${var.private_ecr_repository}/juspaydotin/hyperswitch-drainer:v1.114.0-standalone"
            version = "v1.116.0"
          }
          controlCenter = {
            enabled = true
            image   = "docker.juspay.io/juspaydotin/hyperswitch-control-center:v1.37.3" # "${var.private_ecr_repository}/juspaydotin/hyperswitch-control-center:v1.37.1"
            version = "v1.37.3"
          }
          sdk = {
            host       = "https://${var.sdk_cdn_domain_name}"
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
            secrets_manager = "no_encryption"
            # aws_kms = {
            #   key_id = var.hyperswitch_kms_key_id
            #   region = data.aws_region.current.name
            # }
          }

          # theme = {
          #   storage = {
          #     file_storage_backend = "aws_s3"
          #     aws_s3 = {
          #       region      = data.aws_region.current.name
          #       bucket_name = "logs-bucket-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
          #     }
          #   }
          # }

          serviceAccountAnnotations = {
            "iam.gke.io/gcp-service-account" = google_service_account.hyperswitch_gsa.email
          }

          proxy = {
            enabled = false
            # http_url           = "http://${var.squid_nlb_dns_name}:3128"
            # https_url          = "http://${var.squid_nlb_dns_name}:3128"
            # bypass_proxy_hosts = "\"localhost,127.0.0.1,.svc,.svc.cluster.local,kubernetes.default.svc,169.254.169.254,.amazonaws.com,${var.rds_cluster_endpoint},${var.elasticache_cluster_endpoint_address},${var.external_alb_distribution_domain_name},${var.sdk_distribution_domain_name}\""
          }

          podAnnotations = {
            "traffic.sidecar.istio.io/excludeOutboundIPRanges" = "10.23.6.12/32"
          }

          secrets = {
            kms_admin_api_key                             = "hyperswitch-admin-api-key"
            kms_jwt_secret                                = "hyperswitch-jwt-secret"
            kms_jwekey_locker_identifier1                 = "hyperswitch-jwekey-locker-identifier1"
            kms_jwekey_locker_identifier2                 = "hyperswitch-jwekey-locker-identifier2"
            kms_jwekey_locker_encryption_key1             = "hyperswitch-jwekey-locker-encryption-key1"
            kms_jwekey_locker_encryption_key2             = "hyperswitch-jwekey-locker-encryption-key2"
            kms_jwekey_locker_decryption_key1             = "hyperswitch-jwekey-locker-decryption-key1"
            kms_jwekey_locker_decryption_key2             = "hyperswitch-jwekey-locker-decryption-key2"
            kms_jwekey_vault_encryption_key               = "hyperswitch-jwekey-vault-encryption-key"
            kms_jwekey_vault_private_key                  = "hyperswitch-jwekey-vault-private-key"
            kms_jwekey_tunnel_private_key                 = "hyperswitch-jwekey-tunnel-private-key"
            kms_jwekey_rust_locker_encryption_key         = "hyperswitch-jwekey-rust-locker-encryption-key"
            kms_connector_onboarding_paypal_client_id     = "hyperswitch-paypal-client-id"
            kms_connector_onboarding_paypal_client_secret = "hyperswitch-paypal-client-secret"
            kms_connector_onboarding_paypal_partner_id    = "hyperswitch-paypal-partner-id"
            kms_key_id                                    = "kms_key"
            kms_key_region                                = "us-central1"
            kms_encrypted_api_hash_key                    = "hyperswitch-kms-encrypted-api-hash-key"
            admin_api_key                                 = "hyperswitch-admin-api-key"
            jwt_secret                                    = "hyperswitch-jwt-secret"
            recon_admin_api_key                           = "hyperswitch-recon-admin-api-key"
            forex_api_key                                 = "hyperswitch-forex-api-key"
            forex_fallback_api_key                        = "hyperswitch-forex-fallback-api-key"
            apple_pay_ppc                                 = "hyperswitch-apple-pay-ppc"
            apple_pay_ppc_key                             = "hyperswitch-apple-pay-ppc-key"
            apple_pay_merchant_cert                       = "hyperswitch-apple-pay-merchant-cert"
            apple_pay_merchant_cert_key                   = "hyperswitch-apple-pay-merchant-cert-key"
            apple_pay_merchant_conf_merchant_cert         = "hyperswitch-apple-pay-merchant-cert"
            apple_pay_merchant_conf_merchant_cert_key     = "hyperswitch-apple-pay-merchant-cert-key"
            apple_pay_merchant_conf_merchant_id           = "hyperswitch-apple-pay-merchant-id"
            pm_auth_key                                   = "hyperswitch-pm-auth-key"
            api_hash_key                                  = "hyperswitch-api-hash-key"
            master_enc_key                                = "hyperswitch-encrypted-master-key"
          }

          google_pay_decrypt_keys = {
            google_pay_root_signing_keys = "hyperswitch-google-pay-keys"
          }

          paze_decrypt_keys = {
            paze_private_key            = "hyperswitch-paze-private-key"
            paze_private_key_passphrase = "hyperswitch-paze-private-key-passphrase"
          }

          user_auth_methods = {
            encryption_key = "hyperswitch-encryption-key"
          }

          locker = {
            locker_enabled          = var.locker_enabled
            locker_public_key       = var.locker_enabled ? var.locker_public_key : "locker-key"
            hyperswitch_private_key = var.locker_enabled ? var.tenant_private_key : "locker-key"
          }

          basilisk = {
            host = "basilisk-host"
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
          enabled = !var.enable_external_postgresql
        }

        externalPostgresql = {
          enabled = var.enable_external_postgresql
          primary = {
            host = var.db_primary_host_endpoint
            auth = {
              username      = "db_user"
              database      = "hyperswitch"
              password      = var.db_password # var.kms_secrets["kms_encrypted_db_pass"]
              plainpassword = var.db_password
            }
          }
          readOnly = {
            host = var.db_reader_host_endpoint
            auth = {
              username      = "db_user"
              database      = "hyperswitch"
              password      = var.db_password # var.kms_secrets["kms_encrypted_db_pass"]
              plainpassword = var.db_password
            }
          }
        }

        redis = {
          enabled = !var.enable_external_redis
        }

        externalRedis = {
          enabled = var.enable_external_redis
          host    = var.redis_host_endpoint
          port    = var.redis_port
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

      "hyperswitch-monitoring" = {
        enabled = false
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.hyperswitch,
    helm_release.istio_services
  ]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  chart      = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  namespace  = "kube-system"

  values = [
    yamlencode({
      image = {
        # repository = "${var.private_ecr_repository}/bitnami/metrics-server"
        tag = "0.7.2"
      }
    })
  ]

  depends_on = [
    null_resource.update_kubeconfig,
    helm_release.istio_services
  ]
}
