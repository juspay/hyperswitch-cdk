echo "##########################################\nInstalling dependencies\n##########################################"
# Install dependencies
npm install -g aws-cdk
cdk --version
os=$(uname)
if [ "$os" == "Linux" ]; then
  sh linux_deps.sh
elif [ "$os" == "Darwin" ]; then
  sh mac_deps.sh
else
  echo "Unsupported operating system."
  exit 1
fi

AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
if [[ $AWS_ARN == *":root"* ]]; then
  echo "ROOT user is not recommended. Please create new user with AdministratorAccess and use their Access Token"
  exit 1
fi
echo "##########################################"
# Read the DB Password and Admin API Key
echo "Please enter the password for your RDS instance: (Min 8 Character Needed [A-Z][a-z][0-9]): "
read -s DB_PASS
echo "Please configure the Admin api key (Required to access Hyperswitch APIs): "
read -s ADMIN_API_KEY
echo "##########################################\nDeploying Hyperswitch Services\n##########################################"
# Deploy the EKS Cluster
AWS_ACCOUNT=$(aws sts get-caller-identity --output json | jq -r .Account)
cdk bootstrap aws://$AWS_ACCOUNT/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN
cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN
# Wait for the EKS Cluster to be deployed
aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name hs-eks-cluster
# Deploy Load balancer and Ingress
echo "##########################################"
sleep 10
APP_HOST=$(kubectl get ingress hyperswitch-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LOGS_HOST=$(kubectl get ingress hyperswitch-logs-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
CONTROL_CENTER_HOST=$(kubectl get ingress hyperswitch-control-center-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
SDK_HOST=$(kubectl get ingress hyperswitch-sdk-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
REDIS_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='RedisHost'].OutputValue" --output text)
DB_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='DbHost'].OutputValue" --output text)
LB_SG=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='LbSecurityGroupId'].OutputValue" --output text)
SDK_URL=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='HyperLoaderUrl'].OutputValue" --output text)
SDK_IMAGE="jeevaramachandran/hyperswitch-web:v1.0.0"
# Deploy the hyperswitch application with the load balancer host name
helm repo add hs https://juspay.github.io/hyperswitch-helm
export MERCHANT_ID=$(curl --silent --location --request POST 'http://'$APP_HOST'/user/v2/signin' \
--header 'Content-Type: application/json' \
--data-raw '{
    "email": "test@gmail.com",
    "password": "admin"
}' | jq -r '.merchant_id')
export PUB_KEY=$(curl --silent --location --request GET 'http://'$APP_HOST'/accounts/'$MERCHANT_ID \
--header 'Accept: application/json' \
--header 'api-key: '$ADMIN_API_KEY | jq -r '.publishable_key')
export API_KEY=$(curl --silent --location --request POST 'http://'$APP_HOST'/api_keys/'$MERCHANT_ID \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'api-key: '$ADMIN_API_KEY \
--data-raw '{"name":"API Key 1","description":null,"expiration":"2038-01-19T03:14:08.000Z"}' | jq -r '.api_key')
curl --silent --location --request POST 'http://'$APP_HOST'/account/'$MERCHANT_ID'/connectors' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'api-key: '$ADMIN_API_KEY \
--data-raw '{"connector_type":"fiz_operations","connector_name":"stripe","connector_account_details":{"auth_type":"HeaderKey","api_key":"'$STRIPE_KEY'"},"test_mode":false,"disabled":false,"payment_methods_enabled":[{"payment_method":"card","payment_method_types":[{"payment_method_type":"credit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"debit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]},{"payment_method":"pay_later","payment_method_types":[{"payment_method_type":"klarna","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"affirm","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"afterpay_clearpay","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]}],"metadata":{"city":"NY","unit":"245"},"connector_webhook_details":{"merchant_secret":"MyWebhookSecret"}}'
helm upgrade --install hypers-v1 hs/hyperswitch-helm --set "application.dashboard.env.apiBaseUrl=http://$APP_HOST,application.sdk.env.hyperswitchPublishableKey=$PUB_KEY,application.sdk.env.hyperswitchSecretKey=$API_KEY,application.sdk.env.hyperswitchServerUrl=http://$APP_HOST,application.sdk.env.hyperSwitchClientUrl=$SDK_URL,application.sdk.image=$SDK_IMAGE,application.dashboard.env.sdkBaseUrl=$SDK_URL/HyperLoader.js,application.server.image=juspaydotin/hyperswitch-router:v1.78.0-standalone,application.server.server_base_url=http://$APP_HOST,application.server.secrets.admin_api_key=$ADMIN_API_KEY,db.host=$DB_HOST,db.password=$DB_PASS,redis.host=$REDIS_HOST,loadBalancer.targetSecurityGroup=$LB_SG" -n hyperswitch
echo "##########################################\nWaiting for the application to be deployed\n##########################################"
sleep 30
echo "App server running on "$APP_HOST
echo "Logs server running on "$LOGS_HOST", Login with username:admin, password:admin, Please change on startup"
echo "Control center server running on "$CONTROL_CENTER_HOST", Login with Email: test@gmail.com, password: admin, Please change on startup"
echo "SDK Demo server running on "$SDK_HOST
echo "##########################################"