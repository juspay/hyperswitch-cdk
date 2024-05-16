#!/bin/sh
yum clean all
yum makecache
yum update -y
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
yum install jq -y
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
. /root/.nvm/nvm.sh
nvm install 18 -y
nvm use 18
npm install -g aws-cdk
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
kubectl version --client
AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn)
AWS_ACCOUNT=$(aws sts get-caller-identity --output json | jq -r .Account)
wget https://github.com/juspay/hyperswitch-cdk/archive/refs/tags/v0.3.0.zip
unzip v0.3.0.zip
cd $(unzip -Z -1 v0.3.0.zip | head -1)

npm install

if [ "$INSTALLATION_MODE" -eq 1 ]; then
    cdk bootstrap aws://$AWS_ACCOUNT/$AWS_REGION -c aws_arn=$AWS_ARN
    cdk deploy --require-approval never -c free_tier=true -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN
    export KUBECONFIG=~/.kube/config
    sleep 10
    STANDALONE_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='StandaloneURL'].OutputValue" --output text)
    CONTROL_CENTER_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='ControlCenterURL'].OutputValue" --output text)
    SDK_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='SdkAssetsURL'].OutputValue" --output text)
    DEMO_APP=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='DemoApp'].OutputValue" --output text)
    export MERCHANT_ID=$( curl --silent --location --request POST 'http://'$STANDALONE_HOST'/user/v2/signin' --header 'Content-Type: application/json' --data-raw '{ "email": "test@gmail.com", "password": "admin"}' | jq -r '.merchant_id')
    export PUB_KEY=$( curl --silent --location --request GET 'http://'$STANDALONE_HOST'/accounts/'$MERCHANT_ID --header 'Accept: application/json' --header 'api-key: '$ADMIN_API_KEY | jq -r '.publishable_key')
    export API_KEY=$( curl --silent --location --request POST 'http://'$STANDALONE_HOST'/api_keys/'$MERCHANT_ID --header 'Content-Type: application/json' --header 'Accept: application/json' --header 'api-key: '$ADMIN_API_KEY --data-raw '{"name":"API Key 1","description":null,"expiration":"2038-01-19T03:14:08.000Z"}' | jq -r '.api_key')
    export CONNECTOR_KEY=$(curl --silent --location --request POST 'http://'$STANDALONE_HOST'/account/'$MERCHANT_ID'/connectors' --header 'Content-Type: application/json' --header 'Accept: application/json' --header 'api-key: '$ADMIN_API_KEY --data-raw '{"connector_type":"fiz_operations","connector_name":"stripe_test","connector_account_details":{"auth_type":"HeaderKey","api_key":"test_key"},"test_mode":true,"disabled":false,"payment_methods_enabled":[{"payment_method":"card","payment_method_types":[{"payment_method_type":"credit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"debit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]},{"payment_method":"pay_later","payment_method_types":[{"payment_method_type":"klarna","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"affirm","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"afterpay_clearpay","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]}],"metadata":{"city":"NY","unit":"245"},"connector_webhook_details":{"merchant_secret":"MyWebhookSecret"}}')
    sleep 240

    # Generate the HTML content
    HTML_CONTENT="
<!DOCTYPE html>
<html>
<body>

<h2>Hyperswitch Services</h2>

<table style="width:100%
    text-align:left">
<tr>
<th>Service</th>
<th>Host</th>
</tr>
<tr>
<td>App server running on</td>
<td><a href="$STANDALONE_HOST" id="app_host">$STANDALONE_HOST</a></td>
</tr>
<tr>
<td>Logs server running on</td>
<td><a href="$DEMO_APP" id="demo app">DEMO_APP</a></td>
</tr>
<tr>
<td>Control center server running on</td>
<td><a href="$CONTROL_CENTER_HOST" id="control_center_host">$CONTROL_CENTER_HOST</a></td>
</tr>
<tr>
<td>Hyperswitch Demo Store running on</td>
<td><a href="$SDK_HOST" id="sdk_host">$SDK_HOST</a></td>
</tr>
</table>

</body>
</html>
"
    echo "$HTML_CONTENT" >cdk.services.html
    aws s3 cp cdk.services.html s3://hyperswitch-schema-$AWS_ACCOUNT-$AWS_REGION/cdk.services.html
else

    LOCKER=""
    if [[ -n "$CARD_VAULT_MASTER_KEY" ]]; then
        LOCKER ="-c master_key=$CARD_VAULT_MASTER_KEY "
        LOCKER ="-c locker_pass=$CARD_VAULT_DB_PASS "
    fi
    # echo `aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[*].VpcId'` >> /dev/null
    # if [ $? -ne 0 ]; then
    #     echo
    #     echo "${green}No default VPC found. Creating one...${reset}"
    #     echo
    #     aws ec2 create-default-vpc
    # fi
    # cdk bootstrap aws://"$AWS_ACCOUNT_ID"/"$AWS_DEFAULT_REGION" -c aws_arn="$AWS_ARN" -c stack=imagebuilder
    # cdk deploy --require-approval never -c stack=imagebuilder $AMI_OPTIONS
    cdk bootstrap aws://$AWS_ACCOUNT/$AWS_REGION -c aws_arn=$AWS_ARN
    if cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN -c master_enc_key=$MASTER_ENC_KEY -c vpn_ips=$VPN_IPS -c base_ami=$base_ami -c envoy_ami=$envoy_ami -c squid_ami=$squid_ami $LOCKER; then
        echo $(aws eks create-addon --cluster-name hs-eks-cluster --addon-name amazon-cloudwatch-observability)
        aws eks update-kubeconfig --region "$AWS_REGION" --name hs-eks-cluster
        # Deploy Load balancer and Ingress
        echo "##########################################"
        sleep 10
        APP_HOST=$(kubectl get ingress hyperswitch-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        LOGS_HOST=$(kubectl get ingress hyperswitch-logs-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        CONTROL_CENTER_HOST=$(kubectl get ingress hyperswitch-control-center-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        SDK_WEB_HOST=$(kubectl get ingress hypers-v1-hyperswitchsdk -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        SDK_HOST=$(kubectl get ingress hyperswitch-sdk-demo-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        SDK_URL=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='HyperLoaderUrl'].OutputValue" --output text)

        # Deploy the hyperswitch application with the load balancer host name
        helm repo add hs https://juspay.github.io/hyperswitch-helm
        export MERCHANT_ID=$(
            curl --silent --location --request POST 'http://'$APP_HOST'/user/signup'
            --header 'Content-Type: application/json'
            --data-raw '{
            "email": "test@gmail.com",
            "password": "admin"
            }' | jq -r '.merchant_id'
            )
        export PUB_KEY=$(
            curl --silent --location --request GET 'http://'$APP_HOST'/accounts/'$MERCHANT_ID
            --header 'Accept: application/json'
            --header 'api-key: '$ADMIN_API_KEY | jq -r '.publishable_key'
        )
        export API_KEY=$(
            curl --silent --location --request POST 'http://'$APP_HOST'/api_keys/'$MERCHANT_ID
            --header 'Content-Type: application/json'
            --header 'Accept: application/json'
            --header 'api-key: '$ADMIN_API_KEY
            --data-raw '{"name":"API Key 1","description":null,"expiration":"2038-01-19T03:14:08.000Z"}' | jq -r '.api_key'
        )
        export CONNECTOR_KEY=$(
            curl --silent --location --request POST 'http://'$APP_HOST'/account/'$MERCHANT_ID'/connectors'
            --header 'Content-Type: application/json'
            --header 'Accept: application/json'
            --header 'api-key: '$ADMIN_API_KEY
            --data-raw '{"connector_type":"fiz_operations","connector_name":"stripe_test","connector_account_details":{"auth_type":"HeaderKey","api_key":"test_key"},"test_mode":true,"disabled":false,"payment_methods_enabled":[{"payment_method":"card","payment_method_types":[{"payment_method_type":"credit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"debit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]},{"payment_method":"pay_later","payment_method_types":[{"payment_method_type":"klarna","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"affirm","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"afterpay_clearpay","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]}],"metadata":{"city":"NY","unit":"245"},"connector_webhook_details":{"merchant_secret":"MyWebhookSecret"}}'
        )
        helm get values -n hyperswitch hypers-v1 >values.yaml
        helm upgrade --install hypers-v1 hs/hyperswitch-helm --set "application.dashboard.env.apiBaseUrl=http://$APP_HOST,application.sdk.env.hyperswitchPublishableKey=$PUB_KEY,application.sdk.env.hyperswitchSecretKey=$API_KEY,application.sdk.env.hyperswitchServerUrl=http://$APP_HOST,application.sdk.env.hyperSwitchClientUrl=$SDK_URL,application.dashboard.env.sdkBaseUrl=$SDK_URL/HyperLoader.js,application.server.server_base_url=http://$APP_HOST,hyperswitchsdk.autoBuild.buildParam.envSdkUrl=http://$SDK_WEB_HOST,hyperswitchsdk.autoBuild.buildParam.envBackendUrl=http://$APP_HOST,services.router.host=http://$APP_HOST" -n hyperswitch -f values.yaml
        sleep 10
        # Generate the HTML content
        HTML_CONTENT="
            <!DOCTYPE html>
            <html>
            <body>

            <h2>Hyperswitch Services</h2>

            <table style="width:100% text-align:left">
            <tr>
            <th>Service</th>
            <th>Host</th>
            </tr>
            <tr>
            <td>HyperloaderJS Hosted at</td>
            <td><a href="https://$SDK_WEB_HOST/0.16.7/v0/HyperLoader.js" id="hyperloaderjs_host">https://$SDK_WEB_HOST/0.16.7/v0/HyperLoader.js</a></td>
            </tr>
            <tr>
            <td>App server running on</td>
            <td><a href="http://$APP_HOST" id="app_host">http://$APP_HOST</a></td>
            </tr>
            <tr>
            <td>Logs server running on</td>
            <td><a href="http://$LOGS_HOST" id="logs_host">http://$LOGS_HOST</a></td>
            </tr>
            <tr>
            <td>Control center server running on</td>
            <td><a href="http://$CONTROL_CENTER_HOST" id="control_center_host">http://$CONTROL_CENTER_HOST</a></td>
            </tr>
            <tr>
            <td>Hyperswitch Demo Store running on</td>
            <td><a href="http://$SDK_HOST" id="sdk_host">http://$SDK_HOST</a></td>
            </tr>
            </table>

            </body>
            </html>
            "
        echo "$HTML_CONTENT" >cdk.services.html
        aws s3 cp cdk.services.html s3://hyperswitch-schema-$AWS_ACCOUNT-$AWS_REGION/cdk.services.html
        if [[ -n "$CARD_VAULT_MASTER_KEY" ]]; then
            sh ./unlock_locker.sh
        fi
        exit 0
    fi
fi
