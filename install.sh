#!/bin/bash

# Function to install a binary only if it's not already installed
install_if_needed() {
  local name="$1"
  local check_command="$2"
  local install_script="$3"

  if ! eval "$check_command" &> /dev/null; thens
    echo "Installing $name..."
    eval "$install_script"
  else
    echo "$name is already installed."
  fi
}

# Install dependencies
install_if_needed "bun" "command -v bun" "curl -fsSL https://bun.sh/install | bash"
install_if_needed "helm" "command -v helm" "brew install helm"
install_if_needed "kubectl" "command -v kubectl" "brew install kubectl"
install_if_needed "cdk" "command -v cdk" "npm install -g aws-cdk"

# Validate installation by printing versions
helm version --short
kubectl version --client --short
cdk --version

while [[ -z "$DB_PASS" ]]; do
    echo "Please enter the DB Passoword for the Master User (Minimum length of 8 Characters [A-Z][a-z][0-9]): "
    read DB_PASS < /dev/tty
done
echo $DB_PASS

while [[ -z "$ADMIN_API_KEY" ]]; do
    echo "Please enter the Admin API Key: "
    read ADMIN_API_KEY < /dev/tty
done

# Replace the DB Password and Admin API Key in the index.ts file
awk -v old="dbpassword" -v new="$DB_PASS" '{gsub(old, new); print}' index.ts > index_new.ts && mv index_new.ts index.ts
awk -v old="test_admin" -v new="$ADMIN_API_KEY" '{gsub(old, new); print}' index.ts > index_new.ts && mv index_new.ts index.ts

# Deploy the EKS Cluster
bun install
AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
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
helm upgrade --install hypers-v1 hs/hyperswitch-helm --set "application.server.server_base_url=http://$APP_HOST,db.host=$DB_HOST,db.password=$DB_PASS,redis.host=$REDIS_HOST,loadBalancer.targetSecurityGroup=$LB_SG" -n hyperswitch 
sleep 30
echo "App server running on "$APP_HOST
echo "Logs server running on "$LOGS_HOST", Login with username:admin, password:admin, Please change on startup"