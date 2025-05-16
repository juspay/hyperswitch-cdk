# Values for hyperswitch-stack Helm chart
# Template variables are enclosed in ${...}

clusterName: ${cluster_name}

loadBalancer:
  targetSecurityGroup: ${lb_security_group_id}

# Prometheus and Alertmanager are disabled in CDK example for this chart
prometheus:
  enabled: false
alertmanager:
  enabled: false

hyperswitch-app:
  loadBalancer:
    targetSecurityGroup: ${lb_security_group_id} # Redundant? Usually one LB for the app.
  
  redis:
    enabled: false # External Redis is used

  services:
    router:
      image: ${private_ecr_prefix}/juspaydotin/hyperswitch-router:v1.113.0-standalone # Ensure version matches ECR
    producer:
      image: ${private_ecr_prefix}/juspaydotin/hyperswitch-producer:v1.113.0-standalone
    consumer:
      image: ${private_ecr_prefix}/juspaydotin/hyperswitch-consumer:v1.113.0-standalone
    controlCenter:
      image: ${private_ecr_prefix}/juspaydotin/hyperswitch-control-center:v1.36.1
    sdk:
      host: "https://${sdk_cloudfront_domain}" # Note: CDK uses https:// this.sdkDistribution.distributionDomainName
      version: ${sdk_version}
      subversion: ${sdk_subversion} # CDK uses "v1" here, but "v0" in sdk_userdata.sh. Clarify.

  server:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-type
                operator: In
                values: ["generic-compute"]
    
    secrets_management:
      secrets_manager: "aws_kms" # Matches CDK
    
    region: ${aws_region}
    bucket_name: ${logs_bucket_name} # e.g., logs-bucket-ACCOUNT-REGION

    serviceAccountAnnotations:
      "eks.amazonaws.com/role-arn": ${hyperswitch_sa_role_arn}

    server_base_url: "https://sandbox.hyperswitch.io" # Parameterize if needed

    secrets:
      podAnnotations:
        # Example from CDK, might need adjustment based on actual network setup
        "traffic.sidecar.istio.io/excludeOutboundIPRanges": "10.23.6.12/32" 
      
      # These are KMS encrypted values fetched from SSM by the application
      # The Helm chart might expect direct values or references to Kubernetes secrets
      # that are populated from these SSM parameters.
      # Assuming the application reads these from environment variables set from k8s secrets,
      # which are in turn populated from SSM.
      # The KmsSecrets class in CDK implies these are read by the app from SSM.
      # The Helm chart values here would typically create k8s secrets from these SSM values.
      # For simplicity, showing direct usage, but this needs careful mapping to chart's capabilities.
      kms_admin_api_key: ${kms_admin_api_key}
      kms_jwt_secret: ${kms_jwt_secret}
      # ... list all other kms_... secrets from the KmsSecrets class in CDK
      # Example for a few more:
      # kms_jwekey_locker_identifier1: ${kms_jwekey_locker_identifier1} 
      # kms_jwekey_locker_encryption_key1: ${kms_jwekey_locker_encryption_key1}
      
      kms_key_id: ${kms_key_id_for_app} # This is the KMS Key ID (not ARN) for the app to use
      kms_key_region: ${aws_region}
      
      # Plain text values that might also be part of the 'secrets' block in the chart
      admin_api_key: ${kms_admin_api_key} # Often duplicated for different internal uses
      jwt_secret: ${kms_jwt_secret}
      master_enc_key: ${kms_encrypted_master_key} # This is the KMS encrypted master key
      
      # Other secrets from KmsSecrets class in CDK:
      # recon_admin_api_key, forex_api_key, apple_pay related keys, pm_auth_key, api_hash_key etc.
      # These need to be available as template variables, fetched from SSM.
      # Example:
      # recon_admin_api_key: ${kms_recon_admin_api_key}
      # api_hash_key: ${kms_api_hash_key} # This might be the encrypted one

    google_pay_decrypt_keys:
      google_pay_root_signing_keys: ${kms_google_pay_root_signing_keys} # From SSM

    paze_decrypt_keys:
      paze_private_key: ${kms_paze_private_key} # From SSM
      paze_private_key_passphrase: ${kms_paze_private_key_passphrase} # From SSM
      
    user_auth_methods:
      encryption_key: ${kms_user_auth_encryption_key} # From SSM (placeholder, map to correct KmsSecrets value)

    locker:
      locker_enabled: ${locker_enabled}
      locker_public_key: "${locker_public_key_pem}" # Direct PEM content
      hyperswitch_private_key: "${tenant_private_key_pem}" # Direct PEM content
      
    basilisk: 
      host: "basilisk-host" # Parameterize if needed
      
    run_env: "sandbox" # Parameterize if needed

  consumer:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-type
                operator: In
                values: ["generic-compute"]
  producer:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-type
                operator: In
                values: ["generic-compute"]
  controlCenter:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-type
                operator: In
                values: ["control-center"]
    env:
      default__features__email: false # Example from CDK

  postgresql:
    enabled: false # External PostgreSQL is used

  externalPostgresql:
    enabled: true
    primary:
      host: ${rds_primary_host}
      auth:
        username: "db_user" # Matches CDK
        database: "hyperswitch" # Matches CDK
        password: ${kms_encrypted_db_pass} # KMS encrypted DB pass from SSM
        plainpassword: ${db_password_plain} # Plain password for initial setup if chart needs it
    readOnly:
      host: ${rds_readonly_host}
      auth:
        username: "db_user"
        database: "hyperswitch"
        password: ${kms_encrypted_db_pass}
        plainpassword: ${db_password_plain}

  externalRedis:
    enabled: true
    host: ${redis_host}
    port: 6379

  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80

  analytics:
    clickhouse:
      enabled: false # CDK disables this by default in this chart
      # password: "dummypassword"
  
  kafka:
    enabled: false # CDK disables this

  clickhouse: # Separate from analytics.clickhouse
    enabled: false # CDK disables this

  "hyperswitch-card-vault": # Embedded card vault chart
    enabled: false # CDK disables this by default in the main stack chart
    # postgresql:
    #   enabled: false
    # server:
    #   secrets:
    #     locker_private_key: # This would be the locker's own private key if vault is internal
    #     tenant_public_key:  # This would be the tenant's public key for the internal vault
    #     master_key:         # Master key for the internal vault
