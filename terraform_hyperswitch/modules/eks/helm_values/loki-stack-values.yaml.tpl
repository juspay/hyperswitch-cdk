# Values for loki-stack Helm chart
# Template variables are enclosed in ${...}

grafana:
  enabled: true
  adminPassword: "admin" # Change this in production
  
  global:
    imageRegistry: ${private_ecr_prefix} # CDK uses this, ensure images are there
  image:
    repository: grafana/grafana # Path within the private_ecr_prefix
    tag: "latest" # Or specific version used in CDK if different
  sidecar:
    image:
      repository: kiwigrid/k8s-sidecar # Path within private_ecr_prefix
      tag: "1.30.3" # Matches CDK
      # sha: "" # Not specified in CDK
    # imagePullPolicy: "IfNotPresent" # Default
    # resources: {} # Default
  
  serviceAccount:
    create: true # The chart should create the SA
    name: "loki-grafana" # Standard name, role is attached via annotations
    annotations:
      "eks.amazonaws.com/role-arn": ${grafana_sa_role_arn}
      
  nodeSelector:
    "node-type": "monitoring" # Matches CDK
    
  ingress:
    enabled: true
    ingressClassName: "alb"
    annotations:
      "alb.ingress.kubernetes.io/backend-protocol": "HTTP"
      "alb.ingress.kubernetes.io/group.name": "hs-logs-alb-ingress-group" # Matches CDK
      "alb.ingress.kubernetes.io/ip-address-type": "ipv4"
      "alb.ingress.kubernetes.io/healthcheck-path": "/api/health" # Grafana health check
      "alb.ingress.kubernetes.io/listen-ports": '[{"HTTP": 80}]' # Or HTTPS if cert managed by ALB
      "alb.ingress.kubernetes.io/load-balancer-attributes": "routing.http.drop_invalid_header_fields.enabled=true"
      "alb.ingress.kubernetes.io/load-balancer-name": "hyperswitch-grafana-logs" # Matches CDK
      "alb.ingress.kubernetes.io/scheme": "internet-facing"
      "alb.ingress.kubernetes.io/tags": "stack=hyperswitch-lb" # Matches CDK
      "alb.ingress.kubernetes.io/security-groups": ${grafana_lb_sg_id}
      "alb.ingress.kubernetes.io/subnets": ${grafana_lb_public_subnets} # Comma-separated list
      "alb.ingress.kubernetes.io/target-type": "ip"
    # hosts: [] # Default host, or specify one
    extraPaths: # Matches CDK structure for paths
      - path: "/"
        pathType: "Prefix"
        backend:
          service: # Chart usually creates a service named like release-grafana
            name: "loki-grafana" # This should match the service name created by the grafana sub-chart
            port:
              number: 80 # Or 3000 if that's the service port

loki:
  enabled: true
  global:
    imageRegistry: ${private_ecr_prefix}
  image:
    repository: grafana/loki
    tag: "latest" # Or specific version
    
  serviceAccount:
    create: true
    name: "loki" # Standard name
    annotations:
      "eks.amazonaws.com/role-arn": ${grafana_sa_role_arn} # Same role for Loki S3 access
      
  nodeSelector:
    "node-type": "monitoring" # Matches CDK
    
  config:
    limits_config:
      enforce_metric_name: false
      max_entries_limit_per_query: 5000
      max_query_lookback: "90d"
      reject_old_samples: true
      reject_old_samples_max_age: "168h"
      retention_period: "100d" # Matches CDK
      retention_stream:
        - period: "7d"
          priority: 1
          selector: '{level="debug"}'
          
    schema_config:
      configs:
        - from: "2024-05-01" # Adjust as needed
          store: "tsdb" # Matches CDK
          object_store: "s3" # Matches CDK
          schema: "v12" # Or v11, v13 depending on Loki version
          index:
            prefix: "loki_index_"
            period: "24h"
          chunks:
            prefix: "loki_chunk_"
            period: "24h"
            
    storage_config:
      boltdb_shipper:
        active_index_directory: "/data/loki/boltdb-shipper-active" # /var/loki/boltdb-shipper-active in some charts
        cache_location: "/data/loki/boltdb-shipper-cache"
        cache_ttl: "24h"
        shared_store: "filesystem" # CDK uses filesystem, but for S3 backend, this might be s3
                                   # If using S3 for main storage, boltdb_shipper might be configured for s3 or disabled if tsdb is primary
      filesystem: # This is for local FS cache if boltdb_shipper.shared_store is filesystem
        directory: "/data/loki/chunks"
      
      # TSDB with S3 is the primary long-term storage in CDK example
      tsdb_shipper:
        active_index_directory: "/data/tsdb-index" # Path inside Loki pods
        cache_location: "/data/tsdb-cache"
        shared_store: "s3" # Matches CDK
        
      aws: # S3 configuration
        bucketnames: ${loki_s3_bucket_name}
        region: ${aws_region}
        # s3forcepathstyle: true # If using MinIO or similar, not for AWS S3 typically
        # endpoint: # For S3 compatible storage
        # access_key_id: # If using IAM user, not recommended for IRSA
        # secret_access_key: 
        
      # Hedging config from CDK
      hedging:
        at: "250ms"
        max_per_second: 20
        up_to: 3

promtail:
  enabled: true
  global:
    imageRegistry: ${private_ecr_prefix}
  image:
    # registry: ${private_ecr_prefix} # Already covered by global.imageRegistry
    repository: grafana/promtail
    tag: "latest" # Or specific version
  
  config:
    snippets:
      extraRelabelConfigs: # Matches CDK
        - source_labels: ['__meta_kubernetes_pod_label_app']
          regex: 'hyperswitch-.*'
          action: keep
      # Add other promtail configs if needed (scrape_configs, etc.)
