#!/bin/bash

sudo yum update -y
sudo yum install docker -y
sudo yum install jq -y
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo yum groupinstall -y "Development Tools"
export LC_ALL=en_US.UTF-8

# start a simple http server to serve the Hyperswitch SDK
backend_url={{router_host}}
hyperswitch_client_url=$(curl ifconfig.me)

cd /
# pull the compiled Hyperswitch SDK from the S3 bucket
sudo curl https://hyperswitch-bucket.s3.amazonaws.com/data.zip --output data.zip
sudo unzip -o data.zip

# Replace the backend_url and hyperswitch_client_url in the SDK
sudo find /data -type f -name "*.js" -exec sed -i "s/backend_url/$backend_url/g" {} \;
sudo find /data -type f -name "*.js" -exec sed -i "s/hyperswitch_client_url/$hyperswitch_client_url/g" {} \;

# folder structure the SDK and serve it using a simple http server
cd /
sudo mkdir -p sdk/{{version}}/{{sub_version}}
sudo mv /data/* /sdk/{{version}}/{{sub_version}}
cd /sdk
nohup python -m SimpleHTTPServer 9090 > /dev/null 2>&1 &
cd /



# Hyperswitch Demo APP [Frontend application]
# Create a merchant and get the keys.
# Required for the frontend application to communicate with the backend application
export MERCHANT_ID=$(curl --silent --location --request POST 'http://{{router_host}}/user/signup' \
  --header 'Content-Type: application/json' \
  --data-raw '{
      "email": "itisatest@gmail.com",
      "password": "admin"
  }' | jq -r '.merchant_id')

export HYPERSWITCH_PUBLISHABLE_KEY=$(curl --silent --location --request GET 'http://{{router_host}}/accounts/'$MERCHANT_ID \
  --header 'Accept: application/json' \
  --header 'api-key: '{{admin_api_key}} | jq -r '.publishable_key')

export HYPERSWITCH_SECRET_KEY=$(curl --silent --location --request POST 'http://{{router_host}}/api_keys/'$MERCHANT_ID \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header 'api-key: '{{admin_api_key}} \
  --data-raw '{"name":"API Key 1","description":null,"expiration":"2038-01-19T03:14:08.000Z"}' | jq -r '.api_key')

export CONNECTOR_KEY=$(curl --silent --location --request POST 'http://{{router_host}}/account/'$MERCHANT_ID'/connectors' \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header 'api-key: '{{admin_api_key}} \
  --data-raw '{"connector_type":"fiz_operations","connector_name":"stripe_test","connector_account_details":{"auth_type":"HeaderKey","api_key":"test_key"},"test_mode":true,"disabled":false,"payment_methods_enabled":[{"payment_method":"card","payment_method_types":[{"payment_method_type":"credit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"debit","card_networks":["Visa","Mastercard"],"minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]},{"payment_method":"pay_later","payment_method_types":[{"payment_method_type":"klarna","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"affirm","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true},{"payment_method_type":"afterpay_clearpay","payment_experience":"redirect_to_url","minimum_amount":1,"maximum_amount":68607706,"recurring_enabled":true,"installment_payment_enabled":true}]}],"metadata":{"city":"NY","unit":"245"},"connector_webhook_details":{"merchant_secret":"MyWebhookSecret"}}' )


cat << EOF >> .env
MERCHANT_ID=$MERCHANT_ID
HYPERSWITCH_PUBLISHABLE_KEY=$HYPERSWITCH_PUBLISHABLE_KEY
HYPERSWITCH_SECRET_KEY=$HYPERSWITCH_SECRET_KEY
CONNECTOR_KEY=$CONNECTOR_KEY
HYPERSWITCH_SERVER_URL=http://$backend_url:80
HYPERSWITCH_CLIENT_URL=http://$hyperswitch_client_url:9090/0.16.7/v0
EOF

docker pull juspaydotin/hyperswitch-web:v1.0.10
docker run --env-file .env -p 5252:5252 juspaydotin/hyperswitch-web:v1.0.10