#!/bin/sh
sudo su
yum update -y
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
yum install jq -y
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
. /.nvm/nvm.sh
nvm install 18 -y
nvm use 18
npm install -g aws-cdk
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv ./kubectl /usr/local/bin/kubectl
kubectl version --client
AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
AWS_ACCOUNT=$(aws sts get-caller-identity --output json | jq -r .Account)
wget https://github.com/juspay/hyperswitch-cdk/archive/refs/heads/main.zip
unzip main.zip
cd $(unzip -Z -1 main.zip| head -1)
npm install
cdk bootstrap aws://$AWS_ACCOUNT/$AWS_REGION -c aws_arn=$AWS_ARN
cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN
aws eks update-kubeconfig --region $AWS_REGION --name hs-eks-cluster
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
export CONNECTOR_KEY=$(curl --silent --location --request POST 'http://'$APP_HOST'/account/'$MERCHANT_ID'/connectors' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'api-key: '$ADMIN_API_KEY \
--data-raw '{"connector_type":"fiz_operations","connector_name":"stripe_test","connector_account_details":{"auth_type":"HeaderKey","api_key":"test_key"},"test_mode":true,"disabled":false,"payment_methods_enabled":[{"payment_method":"card","payment_method_types":[{"payment_method_type":"credit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"debit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]},{"payment_method":"pay_later","payment_method_types":[{"payment_method_type":"klarna","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"affirm","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"afterpay_clearpay","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]}],"metadata":{"city":"NY","unit":"245"},"connector_webhook_details":{"merchant_secret":"MyWebhookSecret"}}' )
helm upgrade --install hypers-v1 hs/hyperswitch-helm --set "application.dashboard.env.apiBaseUrl=http://$APP_HOST,application.sdk.env.hyperswitchPublishableKey=$PUB_KEY,application.sdk.env.hyperswitchSecretKey=$API_KEY,application.sdk.env.hyperswitchServerUrl=http://$APP_HOST,application.sdk.env.hyperSwitchClientUrl=$SDK_URL,application.sdk.image=$SDK_IMAGE,application.dashboard.env.sdkBaseUrl=$SDK_URL/HyperLoader.js,application.server.image=juspaydotin/hyperswitch-router:v1.78.0-standalone,application.server.server_base_url=http://$APP_HOST,application.server.secrets.admin_api_key=$ADMIN_API_KEY,db.host=$DB_HOST,db.password=$DB_PASS,redis.host=$REDIS_HOST,loadBalancer.targetSecurityGroup=$LB_SG" -n hyperswitch
aws cloudformation get-template --stack-name my-stack > template.json

# Load the existing template.json file
TEMPLATE=$(cat template.json)

# Append the desired values to the outputs section
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.APP_HOST = {"Value": "'"$APP_HOST"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.DB_HOST = {"Value": "'"$DB_HOST"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.ADMIN_API_KEY = {"Value": "'"$ADMIN_API_KEY"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.DB_PASS = {"Value": "'"$DB_PASS"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.SDK_URL = {"Value": "'"$SDK_URL"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.SDK_IMAGE = {"Value": "'"$SDK_IMAGE"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.LB_SG = {"Value": "'"$LB_SG"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.REDIS_HOST = {"Value": "'"$REDIS_HOST"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.MERCHANT_ID = {"Value": "'"$MERCHANT_ID"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.PUB_KEY = {"Value": "'"$PUB_KEY"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.API_KEY = {"Value": "'"$API_KEY"'"}')
TEMPLATE=$(echo "$TEMPLATE" | jq '.Outputs.CONNECTOR_KEY = {"Value": "'"$CONNECTOR_KEY"'"}')

echo "$TEMPLATE" > template.json

aws cloudformation update-stack --stack-name my-stack --template-body file://template.json