# Install dependencies
curl -fsSL https://bun.sh/install | bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
npm install -g aws-cdk
cdk --version

# Read the DB Password and Admin API Key
echo "Enter DB Password (Min 8 Character Needed without special chars): "  
read DB_PASS
echo "Enter Admin API Key: "  
read ADMIN_API_KEY
echo $DB_PASS" "$ADMIN_API_KEY
# Replace the DB Password and Admin API Key in the index.ts file
awk -v old="dbpassword" -v new="$DB_PASS" '{gsub(old, new); print}' index.ts > index_new.ts && mv index_new.ts index.ts
awk -v old="test_admin" -v new="$ADMIN_API_KEY" '{gsub(old, new); print}' index.ts > index_new.ts && mv index_new.ts index.ts

# Deploy the EKS Cluster
bun install
AWS_ROLE=$(aws sts get-caller-identity --output json | jq -r .Arn | cut -d'/' -f2)
bun cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_role=$AWS_ROLE
# Wait for the EKS Cluster to be deployed
aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name hs-eks-cluster
# Deploy Load balancer and Ingress
bun cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_role=$AWS_ROLE -c enableLoki=true -c triggerDbMigration=true
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