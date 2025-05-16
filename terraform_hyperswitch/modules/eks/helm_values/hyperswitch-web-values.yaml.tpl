# Values for hyperswitch-web Helm chart
# Template variables are enclosed in ${...}

# Assuming the chart structure is similar to the app chart or has these specific values.
# This is based on the limited info in CDK for this chart.

# services:
#   router:
#     host: "http://localhost:8080" # This seems to be a default if app is local, adjust if it points to the actual app service
#   sdkDemo:
#     image: "juspaydotin/hyperswitch-web:v0.109.2" # Parameterize image and tag if needed
#     hyperswitchPublishableKey: "${publishable_key}" # This needs to be sourced, perhaps from a created merchant
#     hyperswitchSecretKey: "${secret_key}"       # This needs to be sourced

loadBalancer:
  targetSecurityGroup: ${lb_security_group_id}

ingress:
  className: "alb"
  annotations:
    "alb.ingress.kubernetes.io/backend-protocol": "HTTP"
    "alb.ingress.kubernetes.io/backend-protocol-version": "HTTP1"
    "alb.ingress.kubernetes.io/group.name": "hyperswitch-web-alb-ingress-group" # Matches CDK
    "alb.ingress.kubernetes.io/ip-address-type": "ipv4"
    "alb.ingress.kubernetes.io/listen-ports": '[{"HTTP": 80}]'
    "alb.ingress.kubernetes.io/load-balancer-name": "hyperswitch-web" # Matches CDK
    "alb.ingress.kubernetes.io/scheme": "internet-facing"
    "alb.ingress.kubernetes.io/security-groups": ${lb_security_group_id}
    "alb.ingress.kubernetes.io/tags": "stack=hyperswitch-lb" # Matches CDK
    "alb.ingress.kubernetes.io/target-type": "ip"
  hosts:
    - host: "" # No specific host in CDK, implies default ALB DNS
      paths:
        - path: "/"
          pathType: "Prefix"

autoBuild: # As per CDK
  forceBuild: false
  gitCloneParam:
    gitVersion: ${sdk_version} # e.g., "0.109.2"
  buildParam:
    envSdkUrl: "https://${sdk_cloudfront_domain}"
  nginxConfig:
    extraPath: "v1"

# Example of how image could be structured if not using autoBuild primarily
# image:
#   repository: ${private_ecr_prefix}/juspaydotin/hyperswitch-web # If using ECR
#   tag: v0.109.2 # Or some other version
#   pullPolicy: IfNotPresent

# Example environment variables if the app needs them directly
# env:
#   HYPERSWITCH_PUBLISHABLE_KEY: ${publishable_key}
#   HYPERSWITCH_SECRET_KEY: ${secret_key}
#   HYPERSWITCH_SERVER_URL: "http://<hyperswitch-app-service-dns>:8080" # Internal k8s service for the main app
#   HYPERSWITCH_CLIENT_URL: "https://${sdk_cloudfront_domain}/${sdk_version}/${sdk_subversion}"
