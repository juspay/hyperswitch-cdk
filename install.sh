export LOG_FILE="cdk.services.log"
function echoLog() {
  echo "$1" | tee -a $LOG_FILE
}
function isValidPass() {
  if [[ ! $1 =~ ^([A-Z]|[a-z])([A-Z]|[a-z]|[0-9]){7,}$ ]]; then
    echo "Error: Input does not match the pattern [A-Z][a-z][0-9] and should have at least 8 characters and start with alphabet."
    exit 1
  fi
}

echo "##########################################\nInstalling dependencies\n##########################################"
# Install dependencies
if ! command -v node &> /dev/null
then
    echo "node could not be found. Please install Node.js 18 or above."
    exit 1
fi
version=$(node -v | cut -d'.' -f1 | tr -d 'v')
if [ "$version" -lt 18 ]
then
  echo "Invalid Node.js version. Expected 18 or above, but got $version."
  exit 1
fi
if aws --version; then
  echo "##########################################\nAWS CLI Installed\n##########################################"
else
  curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
  sudo installer -pkg AWSCLIV2.pkg -target /
fi
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Please rerun \`sh install.sh\` with Sudo access"
    exit 1
fi
npm install -g aws-cdk
if ! command -v cdk &> /dev/null
then
    echo "AWS CDK could not be found. Please rerun \`sh install.sh\` with Sudo access"
    exit 1
fi
cdk --version
os=$(uname)
if [ "$os" = "Linux" ]; then
  sh linux_deps.sh
elif [ "$os" = "Darwin" ]; then
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
isValidPass $DB_PASS
echo "Please configure the Admin api key (Required to access Hyperswitch APIs): "
read -s ADMIN_API_KEY

echo "$(tput bold)$(tput setaf 1)If you need Card Vault, please create master key by following below steps, leave it empty if you don't need it$(tput sgr0)"
echo "$(tput bold)$(tput setaf 3)To generate the master key, you can use the utility bundled within \n(https://github.com/juspay/hyperswitch-card-vault)$(tput sgr0)"
echo "$(tput bold)$(tput setaf 3)If you have cargo installed you can run \n(cargo install --git https://github.com/juspay/hyperswitch-card-vault --bin utils --root . && ./bin/utils master-key && rm ./bin/utils && rmdir ./bin)$(tput sgr0)"

echo "Please input the encrypted master key (optional): "
read -s MASTER_KEY
LOCKER=""
if [[ -n "$MASTER_KEY" ]]; then
  LOCKER+="-c master_key=$MASTER_KEY "
  echo "Please enter the database password to be used for locker: "
  read -s LOCKER_DB_PASS
  isValidPass $LOCKER_DB_PASS
  LOCKER+="-c locker_pass=$LOCKER_DB_PASS "
fi
echo "##########################################\nDeploying Hyperswitch Services\n##########################################"
# Deploy the EKS Cluster
AWS_ACCOUNT=$(aws sts get-caller-identity --output json | jq -r .Account)
npm install
cdk bootstrap aws://$AWS_ACCOUNT/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN
if cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN $LOCKER ; then
  # Wait for the EKS Cluster to be deployed
  aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name hs-eks-cluster
  # Deploy Load balancer and Ingress
  echo "##########################################"
  sleep 10
  APP_HOST=$(kubectl get ingress hyperswitch-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  LOGS_HOST=$(kubectl get ingress hyperswitch-logs-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  CONTROL_CENTER_HOST=$(kubectl get ingress hyperswitch-control-center-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  SDK_HOST=$(kubectl get ingress hyperswitch-sdk-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  SDK_URL=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='HyperLoaderUrl'].OutputValue" --output text)
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
  export CONNECTOR_KEY=$(curl --silent --location --request POST 'http://'$APP_HOST'/account/'$MERCHANT_ID'/connectors' \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header 'api-key: '$ADMIN_API_KEY \
  --data-raw '{"connector_type":"fiz_operations","connector_name":"stripe_test","connector_account_details":{"auth_type":"HeaderKey","api_key":"test_key"},"test_mode":true,"disabled":false,"payment_methods_enabled":[{"payment_method":"card","payment_method_types":[{"payment_method_type":"credit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"debit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]},{"payment_method":"pay_later","payment_method_types":[{"payment_method_type":"klarna","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"affirm","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"afterpay_clearpay","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]}],"metadata":{"city":"NY","unit":"245"},"connector_webhook_details":{"merchant_secret":"MyWebhookSecret"}}' )
  echo "##########################################\nPlease wait for the application to deploy - Avg Wait time: ~4 mins\n##########################################"
  helm get values -n hyperswitch hypers-v1 > values.yaml
  helm upgrade --install hypers-v1 hs/hyperswitch-helm --set "application.dashboard.env.apiBaseUrl=http://$APP_HOST,application.sdk.env.hyperswitchPublishableKey=$PUB_KEY,application.sdk.env.hyperswitchSecretKey=$API_KEY,application.sdk.env.hyperswitchServerUrl=http://$APP_HOST,application.sdk.env.hyperSwitchClientUrl=$SDK_URL,application.dashboard.env.sdkBaseUrl=$SDK_URL/HyperLoader.js,application.server.server_base_url=http://$APP_HOST" -n hyperswitch -f values.yaml
  sleep 240
  export BOLD=$(tput bold)
  export BLUE=$(tput setaf 4)
  export GREEN=$(tput setaf 2)
  export YELLOW=$(tput setaf 3)
  export RESET=$(tput sgr0)
  echoLog "--------------------------------------------------------------------------------"
  echoLog "$BOLD Service                           Host$RESET"
  echoLog "--------------------------------------------------------------------------------"
  echoLog "$GREEN HyperloaderJS Hosted at           $BLUE"$SDK_URL/HyperLoader.js"$RESET"
  echoLog "$GREEN App server running on             $BLUE"http://$APP_HOST"$RESET"
  echoLog "$GREEN Logs server running on            $BLUE"http://$LOGS_HOST"$RESET, Login with $YELLOW username: admin, password: admin$RESET , Please change on startup"
  echoLog "$GREEN Control center server running on  $BLUE"http://$CONTROL_CENTER_HOST"$RESET, Login with $YELLOW Email: test@gmail.com, password: admin$RESET , Please change on startup"
  echoLog "$GREEN Hyperswitch Demo Store running on $BLUE"http://$SDK_HOST"$RESET"
  echoLog "--------------------------------------------------------------------------------"
  echoLog "##########################################"
  echo "$BLUE Please run 'cat cdk.services.log' to view the services details again"$RESET
  exit 0
else
  aws cloudformation delete-stack --stack-name CDKToolkit
fi
