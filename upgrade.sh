#! /usr/bin/env bash
# Setting up color and style variables
bold=$(tput bold)
blue=$(tput setaf 4)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0)

export LOG_FILE="cdk.services.log"
function echoLog() {
    echo "$1" | tee -a $LOG_FILE
}

sh ./bash/deps.sh

# Deploy Load balancer and Ingress
echo "##########################################"
ADMIN_API_KEY=$1
CARD_VAULT=$2
APP_PROXY_SETUP=$3
KEYMANAGER_ENABLED=$4
LOGS_HOST=$(kubectl get ingress hyperswitch-logs-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
INGRESS_CONTROL_CENTER_HOST=$(kubectl get ingress hyperswitch-control-center-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
CONTROL_CENTER_HOST=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[?DomainName=='${INGRESS_CONTROL_CENTER_HOST}']].DomainName" --output text);
#SDK_HOST=$(kubectl get ingress hyperswitch-sdk-demo-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') #sdk-demo-ingress NOT FOUND
SDK_URL=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='SdkDistribution'].OutputValue" --output text)

# Determine INGRESS_APP_HOST
if [[ "$APP_PROXY_SETUP" == "y" ]]; then
    EXT_ALB_DNS=$(aws elbv2 describe-load-balancers --names external-lb --query 'LoadBalancers[0].DNSName' --output text)
    SQUID_ALB_DNS=$(aws elbv2 describe-load-balancers --names squid-nlb --query 'LoadBalancers[0].DNSName' --output text)
else
    EXT_ALB_DNS=""
    SQUID_ALB_DNS=""
fi

if [ -n "$EXT_ALB_DNS" ] && [ "$EXT_ALB_DNS" != "null" ]; then
    INGRESS_APP_HOST="$EXT_ALB_DNS"
    echo "Using External ALB DNS for INGRESS_APP_HOST: $INGRESS_APP_HOST"
else 
    INGRESS_APP_HOST=$(kubectl get ingress hyperswitch-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$INGRESS_APP_HOST" ]; then
        echo "${bold}${red}Error: Failed to retrieve DNS for hyperswitch-alb-ingress Exiting.${reset}"
        exit 1
    fi
    echo "Using hyperswitch-alb-ingress DNS for INGRESS_APP_HOST: $INGRESS_APP_HOST"
fi

APP_HOST=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[?DomainName=='${INGRESS_APP_HOST}']].DomainName" --output text)
if [ -z "$APP_HOST" ]; then
    echo "${bold}${yellow}Warning: Could not find CloudFront distribution for INGRESS_APP_HOST '$INGRESS_APP_HOST'. Using INGRESS_APP_HOST directly for APP_HOST.${reset}"
    APP_HOST="$INGRESS_APP_HOST"
fi

# Configure proxy settings if Squid proxy is available
PROXY_CONFIG=""
if [ -n "$SQUID_ALB_DNS" ] && [ "$SQUID_ALB_DNS" != "null" ]; then
    echo "Squid proxy detected: $SQUID_ALB_DNS"
    
    # Get RDS and Redis hostnames for bypass list
    RDS_HOST=$(helm get values -n hyperswitch hypers-v1 -o json 2>/dev/null | jq -r '.["hyperswitch-app"].externalPostgresql.primary.host // ""')
    REDIS_HOST=$(helm get values -n hyperswitch hypers-v1 -o json 2>/dev/null | jq -r '.["hyperswitch-app"].externalRedis.host // ""')
    
    # Build bypass proxy hosts list
    BYPASS_HOSTS="localhost,127.0.0.1,.svc,.svc.cluster.local,kubernetes.default.svc,169.254.169.254,.amazonaws.com"
    if [ -n "$RDS_HOST" ] && [ "$RDS_HOST" != "null" ]; then
        BYPASS_HOSTS="$BYPASS_HOSTS,$RDS_HOST"
    fi
    if [ -n "$REDIS_HOST" ] && [ "$REDIS_HOST" != "null" ]; then
        BYPASS_HOSTS="$BYPASS_HOSTS,$REDIS_HOST"
    fi

    cat > proxy-values.yaml <<-EOF
    hyperswitch-app:
      server:
        proxy:
          enabled: true
          http_url: http://$SQUID_ALB_DNS:3128
          https_url: http://$SQUID_ALB_DNS:3128
          bypass_proxy_hosts: "\"$BYPASS_HOSTS\""
EOF
    
    echo "Proxy configuration will be applied"
else
    cat > proxy-values.yaml <<-EOF
    hyperswitch-app:
      server:
        proxy:
          enabled: false
EOF
fi

# Configure keymanager settings if enabled
KEYMANAGER_CONFIG=""
if [[ "$KEYMANAGER_ENABLED" == "y" ]]; then
    echo "Configuring keymanager integration..."
    
    # Check if keymanager namespace exists
    if kubectl get namespace keymanager &>/dev/null; then
        # Retrieve certificates from SSM
        KEYMANAGER_CA_CERT=$(aws ssm get-parameter --name "/keymanager/ca_cert" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
        KEYMANAGER_CLIENT_CERT=$(aws ssm get-parameter --name "/keymanager/client_cert" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
        
        if [ -n "$KEYMANAGER_CA_CERT" ] && [ -n "$KEYMANAGER_CLIENT_CERT" ]; then
            # Build keymanager configuration for helm
            KEYMANAGER_CONFIG="--set hyperswitch-app.server.keymanager.enabled=true \
                              --set hyperswitch-app.server.keymanager.url=https://keymanager.keymanager.svc.cluster.local \
                              --set hyperswitch-app.server.secrets.keymanager.ca=\"$KEYMANAGER_CA_CERT\" \
                              --set hyperswitch-app.server.secrets.keymanager.cert=\"$KEYMANAGER_CLIENT_CERT\""
            
            echo "Keymanager configuration loaded successfully"
        else
            echo "Warning: Could not retrieve keymanager certificates from SSM"
        fi
    else
        echo "Warning: Keymanager namespace not found, skipping keymanager configuration"
    fi
fi

# Deploy the hyperswitch application with the load balancer host name
helm repo add hs https://juspay.github.io/hyperswitch-helm/ --force-update
export MERCHANT_ID=$(curl --connect-timeout 5 --retry 5 --retry-delay 30 --silent --location --request POST 'https://'$APP_HOST'/user/signup' \
    --header 'Content-Type: application/json' \
    --data-raw '{
"email": "test@gmail.com",
"password": "admin"
}' | jq -r '.merchant_id')
export PUB_KEY=$(curl --silent --location --request GET 'https://'$APP_HOST'/accounts/'$MERCHANT_ID \
    --header 'Accept: application/json' \
    --header 'api-key: '$ADMIN_API_KEY | jq -r '.publishable_key')
export API_KEY=$(curl --silent --location --request POST 'https://'$APP_HOST'/api_keys/'$MERCHANT_ID \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header 'api-key: '$ADMIN_API_KEY \
    --data-raw '{"name":"API Key 1","description":null,"expiration":"2038-01-19T03:14:08.000Z"}' | jq -r '.api_key')
export CONNECTOR_KEY=$(curl --silent --location --request POST 'https://'$APP_HOST'/account/'$MERCHANT_ID'/connectors' \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header 'api-key: '$ADMIN_API_KEY \
    --data-raw '{"connector_type":"fiz_operations","connector_name":"stripe_test","connector_account_details":{"auth_type":"HeaderKey","api_key":"test_key"},"test_mode":true,"disabled":false,"payment_methods_enabled":[{"payment_method":"card","payment_method_types":[{"payment_method_type":"credit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"debit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]},{"payment_method":"pay_later","payment_method_types":[{"payment_method_type":"klarna","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"affirm","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"afterpay_clearpay","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]}],"metadata":{"city":"NY","unit":"245"},"connector_webhook_details":{"merchant_secret":"MyWebhookSecret"}}')
printf "##########################################\nPlease wait for the application to deploy \n##########################################"
APP_ENV="hyperswitch-app"
SDK_ENV="hyperswitchsdk.services"
SDK_BUILD="hyperswitchsdk.autoBuild.buildParam"
HYPERLOADER="https://$SDK_URL/web/0.125.0/v1/HyperLoader.js"
VERSION="0.2.12"
helm upgrade --install hypers-v1 hs/hyperswitch-stack --version "$VERSION" \
    --set "$SDK_ENV.router.host=https://$APP_HOST" \
    --set "$SDK_ENV.sdkDemo.hyperswitchPublishableKey=$PUB_KEY" \
    --set "$SDK_ENV.sdkDemo.hyperswitchSecretKey=$API_KEY" \
    --set "$APP_ENV.services.sdk.host=https://$SDK_URL" \
    --set "$APP_ENV.services.router.host=https://$APP_HOST" \
    --set "$APP_ENV.server.multitenancy.tenants.public.base_url=https://$APP_HOST" \
    --set "$APP_ENV.server.multitenancy.tenants.public.user.control_center_url=https://$CONTROL_CENTER_HOST" \
    --set "$SDK_BUILD.envSdkUrl=https://$SDK_URL" \
    --set "$SDK_BUILD.envBackendUrl=https://$APP_HOST" \
    --values proxy-values.yaml \
    $KEYMANAGER_CONFIG \
    -n hyperswitch -f values.yaml

echoLog "--------------------------------------------------------------------------------"
echoLog "$bold Service                           Host$reset"
echoLog "--------------------------------------------------------------------------------"
echoLog "$green HyperloaderJS Hosted at           $blue$HYPERLOADER$reset"
echoLog "$green App server running on             $blue"https://$APP_HOST/health"$reset"
echoLog "$green Logs server running on            $blue"https://$LOGS_HOST"$reset, Login with $yellow username: admin, password: admin$reset , Please change on startup"
echoLog "$green Control center server running on  $blue"https://$CONTROL_CENTER_HOST"$reset, Login with $yellow Email: test@gmail.com, password: admin$reset , Please change on startup"
#echoLog "$green Hyperswitch Demo Store running on $blue"https://$SDK_HOST"$reset"
echoLog "--------------------------------------------------------------------------------"
echoLog "##########################################"
echoLog "$blue Please run 'cat cdk.services.log' to view the services details again$reset"
if [[ "$2" == "y" ]]; then
    sh ./unlock_locker.sh
fi
