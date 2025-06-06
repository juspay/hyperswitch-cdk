#! /usr/bin/env bash
# Setting up color and style variables
bold=$(tput bold)
blue=$(tput setaf 4)
green=$(tput setaf 2)
reset=$(tput sgr0)

export LOG_FILE="cdk.services.log"
function echoLog() {
    echo "$1" | tee -a $LOG_FILE
}

sh ./bash/deps.sh

# Deploy Load balancer and Ingress
echo "##########################################"
ADMIN_API_KEY=$1
LOGS_HOST=$(kubectl get ingress hyperswitch-logs-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
INGRESS_CONTROL_CENTER_HOST=$(kubectl get ingress hyperswitch-control-center-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
CONTROL_CENTER_HOST=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[?DomainName=='${INGRESS_CONTROL_CENTER_HOST}']].DomainName" --output text);
SDK_HOST=$(kubectl get ingress hyperswitch-sdk-demo-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') #sdk-demo-ingress NOT FOUND
SDK_URL=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='SdkDistribution'].OutputValue" --output text)
INGRESS_APP_HOST=$(kubectl get ingress hyperswitch-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}');
APP_HOST=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[?DomainName=='${INGRESS_APP_HOST}']].DomainName" --output text);

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
HYPERLOADER="https://$SDK_URL/web/0.121.2/v1/HyperLoader.js"
VERSION="0.2.4"
helm upgrade --install hypers-v1 hs/hyperswitch-stack --version "$VERSION" --set "$SDK_ENV.router.host=https://$APP_HOST,$SDK_ENV.sdkDemo.hyperswitchPublishableKey=$PUB_KEY,$SDK_ENV.sdkDemo.hyperswitchSecretKey=$API_KEY,$APP_ENV.services.sdk.host=https://$SDK_URL,$APP_ENV.services.router.host=https://$APP_HOST,$SDK_BUILD.envSdkUrl=https://$SDK_URL,$SDK_BUILD.envBackendUrl=https://$APP_HOST" -n hyperswitch -f values.yaml

echoLog "--------------------------------------------------------------------------------"
echoLog "$bold Service                           Host$reset"
echoLog "--------------------------------------------------------------------------------"
echoLog "$green HyperloaderJS Hosted at           $blue$HYPERLOADER$reset"
echoLog "$green App server running on             $blue"https://$APP_HOST/health"$reset"
echoLog "$green Logs server running on            $blue"https://$LOGS_HOST"$reset, Login with $YELLOW username: admin, password: admin$reset , Please change on startup"
echoLog "$green Control center server running on  $blue"https://$CONTROL_CENTER_HOST"$reset, Login with $YELLOW Email: test@gmail.com, password: admin$reset , Please change on startup"
#echoLog "$green Hyperswitch Demo Store running on $blue"https://$SDK_HOST"$reset"
echoLog "--------------------------------------------------------------------------------"
echoLog "##########################################"
echoLog "$blue Please run 'cat cdk.services.log' to view the services details again$reset"
if [[ "$2" == "y" ]]; then
    sh ./unlock_locker.sh
fi