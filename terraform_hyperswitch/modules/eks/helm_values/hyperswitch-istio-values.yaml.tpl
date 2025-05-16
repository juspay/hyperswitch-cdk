# Values for hyperswitch-istio Helm chart (TrafficControl)
# Template variables are enclosed in ${...}

# image:
#   version: "v1o107o0" # This seems to be a custom image tag used in CDK. 
                        # Ensure this image exists in your ECR or adjust.
                        # The chart might have its own image settings.

ingress:
  enabled: true
  className: "alb" # For AWS Load Balancer Controller
  annotations:
    "alb.ingress.kubernetes.io/backend-protocol": "HTTP"
    "alb.ingress.kubernetes.io/backend-protocol-version": "HTTP1"
    "alb.ingress.kubernetes.io/group.name": "hyperswitch-istio-app-alb-ingress-group" # Matches CDK
    "alb.ingress.kubernetes.io/healthcheck-interval-seconds": "5"
    "alb.ingress.kubernetes.io/healthcheck-path": "/healthz/ready" # Istio health check path
    "alb.ingress.kubernetes.io/healthcheck-port": "15021"          # Istio health check port
    "alb.ingress.kubernetes.io/healthcheck-protocol": "HTTP"
    "alb.ingress.kubernetes.io/healthcheck-timeout-seconds": "2"
    "alb.ingress.kubernetes.io/healthy-threshold-count": "5"
    "alb.ingress.kubernetes.io/ip-address-type": "ipv4"
    "alb.ingress.kubernetes.io/listen-ports": '[{"HTTP": 80}]' # Or HTTPS: 443 if SSL is handled by ALB
    "alb.ingress.kubernetes.io/load-balancer-attributes": "routing.http.drop_invalid_header_fields.enabled=true,routing.http.xff_client_port.enabled=true,routing.http.preserve_host_header.enabled=true"
    "alb.ingress.kubernetes.io/scheme": "internal" # This creates an internal ALB
    "alb.ingress.kubernetes.io/security-groups": ${lb_security_group_id}
    "alb.ingress.kubernetes.io/subnets": ${internal_lb_subnets} # Comma-separated list of subnet IDs for internal ALB
    "alb.ingress.kubernetes.io/target-type": "ip"
    "alb.ingress.kubernetes.io/unhealthy-threshold-count": "3"
  
  hosts: # This structure might vary based on the chart. This is a common pattern.
    # If the chart expects a single host or specific path configurations, adjust accordingly.
    # The CDK example implies a default host routing to istio-ingressgateway service.
    # Example:
    # - host: myapp.internal # Optional: if you have a specific internal DNS name
    paths:
      - path: "/"
        pathType: "Prefix"
        port: 80 # Port of the istio-ingressgateway service
        name: "istio-ingress" # Service name of istio-ingressgateway
      - path: "/healthz/ready" # Exposing health check through ALB
        pathType: "Prefix"
        port: 15021
        name: "istio-ingress" # Service name of istio-ingressgateway
