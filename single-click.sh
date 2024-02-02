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
LOCKER=""
if [[ -n "$MASTER_KEY" ]]; then
  LOCKER+="-c master_key=$MASTER_KEY "
  LOCKER+="-c locker_pass=$LOCKER_DB_PASS "
fi
cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN -c additional_aws_arn=$ADMIN_AWS_ARN $LOCKER
aws eks update-kubeconfig --region $AWS_REGION --name hs-eks-cluster
export KUBECONFIG=~/.kube/config
sleep 10
APP_HOST=$(kubectl get ingress hyperswitch -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LOGS_HOST=$(kubectl get ingress hyperswitch-logs -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
CONTROL_CENTER_HOST=$(kubectl get ingress hyperswitch-control-center -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
SDK_HOST=$(kubectl get ingress hyperswitch-sdk-demo -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
REDIS_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='RedisHost'].OutputValue" --output text)
DB_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='DbHost'].OutputValue" --output text)
LB_SG=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='LbSecurityGroupId'].OutputValue" --output text)
SDK_URL=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='HyperLoaderUrl'].OutputValue" --output text)
SDK_IMAGE="juspaydotin/hyperswitch-web:v1.0.1"
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
helm get values -n hyperswitch hypers-v1 > values.yaml
helm upgrade --install hypers-v1 hs/hyperswitch-helm --set "application.dashboard.env.apiBaseUrl=http://$APP_HOST,application.sdk.env.hyperswitchPublishableKey=$PUB_KEY,application.sdk.env.hyperswitchSecretKey=$API_KEY,application.sdk.env.hyperswitchServerUrl=http://$APP_HOST,application.sdk.env.hyperSwitchClientUrl=$SDK_URL,application.dashboard.env.sdkBaseUrl=$SDK_URL/HyperLoader.js,application.server.server_base_url=http://$APP_HOST" -n hyperswitch -f values.yaml
sleep 240
SDK_URL=$SDK_URL/HyperLoader.js
APP_HOST=http://$APP_HOST
LOGS_HOST=http://$LOGS_HOST
CONTROL_CENTER_HOST=http://$CONTROL_CENTER_HOST
SDK_HOST=http://$SDK_HOST

# Generate the HTML content
HTML_CONTENT="
<!DOCTYPE html>
<html>
<body>

<h2>Hyperswitch Services</h2>

<table style=\"width:100%;text-align:left\">
  <tr>
    <th>Service</th>
    <th>Host</th>
  </tr>
  <tr>
    <td>HyperloaderJS Hosted at</td>
    <td><a href=\"$SDK_URL\" id=\"sdk_url\">$SDK_URL</a></td>
  </tr>
  <tr>
    <td>App server running on</td>
    <td><a href=\"$APP_HOST\" id=\"app_host\">$APP_HOST</a></td>
  </tr>
  <tr>
    <td>Logs server running on</td>
    <td><a href=\"$LOGS_HOST\" id=\"logs_host\">$LOGS_HOST</a> <span>, Login with username: admin, password: admin , Please change on startup</span> </td>
  </tr>
  <tr>
    <td>Control center server running on</td>
    <td><a href=\"$CONTROL_CENTER_HOST\" id=\"control_center_host\">$CONTROL_CENTER_HOST</a> <span>Login with Email: test@gmail.com, password: admin , Please change on startup</span> </td>
  </tr>
  <tr>
    <td>Hyperswitch Demo Store running on</td>
    <td><a href=\"$SDK_HOST\" id=\"sdk_host\">$SDK_HOST</a></td>
  </tr>
</table>

</body>
</html>
"
echo "$HTML_CONTENT" > cdk.services.html
aws s3 cp cdk.services.html s3://hyperswitch-schema-$AWS_ACCOUNT-$AWS_REGION/cdk.services.html