yum update -y
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
yum install jq -y
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
. ~/.nvm/nvm.sh
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
cdk bootstrap aws://$AWS_ACCOUNT/us-east-1 -c aws_arn=$AWS_ARN
cdk deploy --require-approval never -c db_pass=dbpassword -c admin_api_key=test_admin -c aws_arn=$AWS_ARN
