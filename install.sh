AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
if [[ $AWS_ARN == *":root"* ]]; then
  echo "ROOT user is not recommended. Please create new user with AdministratorAccess and use their Access Token"
  exit 1
fi
# Install dependencies
curl -fsSL https://bun.sh/install | bash
npm install -g aws-cdk
cdk --version
os=$(uname)
if [ "$os" == "Linux" ]; then
  ./linux_deps.sh
elif [ "$os" == "Darwin" ]; then
  ./mac_deps.sh
else
  echo "Unsupported operating system."
  exit 1
fi

# Read the DB Password and Admin API Key
echo "Please enter the password for your RDS instance: (Min 8 Character Needed [A-Z][a-z][0-9]): "  
read -s DB_PASS
echo "Please configure the Admin api key (Required to access Hyperswitch APIs): "  
read -s ADMIN_API_KEY

# Deploy the EKS Cluster
bun install
AWS_ACCOUNT=$(aws sts get-caller-identity --output json | jq -r .Account)
bun cdk bootstrap aws://$AWS_ACCOUNT/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN
bun cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN
# Wait for the EKS Cluster to be deployed
aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name hs-eks-cluster
# Deploy Load balancer and Ingress
bun cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN -c enableLoki=true -c triggerDbMigration=true
echo "Waiting for the Load Balancer to be deployed"
sleep 30
APP_HOST=$(kubectl get ingress hyperswitch-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LOGS_HOST=$(kubectl get ingress hyperswitch-logs-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $APP_HOST
echo $LOGS_HOST
REDIS_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='redisHost'].OutputValue" --output text)
DB_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='dbHost'].OutputValue" --output text)
LB_SG=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='lbSecurityGroupId'].OutputValue" --output text)
# Delete app-server and consumer deployments
kubectl delete deployment hyperswitch-consumer-consumer-v1o47o0ohotfixo3 -n hyperswitch
kubectl delete deployment hyperswitch-server-v1o52o1v2 -n hyperswitch 
# Deploy the hyperswitch application with the load balancer host name
helm repo add hs https://juspay.github.io/hyperswitch-helm
helm upgrade --install hypers-v1 hs/hyperswitch-helm --set "application.server.server_base_url=http://$APP_HOST,db.host=$DB_HOST,db.password=$DB_PASS,redis.host=$REDIS_HOST,loadBalancer.targetSecurityGroup=$LB_SG" -n hyperswitch 
sleep 30
echo "App server running on "$APP_HOST
echo "Logs server running on "$LOGS_HOST", Login with username:admin, password:admin, Please change on startup"