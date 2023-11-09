# Install dependencies
npm install -g yarn
npm install -g aws-cdk@v1.134

# Download Hyperswitch
wget https://github.com/juspay/hyperswitch-cdk/archive/refs/heads/test.zip
unzip v1.52.0.zip
cd $(unzip -Z -1 v1.52.0.zip| head -1)

# Copy the AWS CDK configuration file to the current directory.
cp extras/cdk.json .
yarn install
export AWS_REGION

echo "Deploy CDK ${AWS_STACK_NAME}"
./deploy --test true

echo "Hyperswitch Deployed ${AWS_STACK_NAME}"