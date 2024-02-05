#! /usr/bin/env bash

# Setting up color and style variables
bold=$(tput bold)
blue=$(tput setaf 4)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0)
white=$(tput setaf 7)
term_width=$(tput cols)
box_width=60
padding="$(printf '%*s' $(( (term_width - box_width) / 2 )) '')"
box_line="$(printf '%*s' $box_width '')"
box_line="${box_line// /-}"

# Checking for AWS credentials
if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_SESSION_TOKEN" ]]; then
    display_error "Missing AWS credentials. Please configure the AWS CLI with your credentials."
    exit 1
fi
# Function to display error messages in red
display_error() {
    echo "${bold}${red}$1${reset}"
}

echo
echo "${green}##########################################${reset}"
echo "${green}       Installing Dependencies${reset}"
echo "${green}##########################################${reset}"
echo
# Function to display a simple loading animation
show_loader() {
    local message=$1
    local pid=$!
    local delay=0.3
    local spinstr='|/-\\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r%s [%c]  " "$message" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%s [Done]   \n" "$message"
}

# Check for Node.js
echo "Checking for Node.js..."
if ! command -v node &> /dev/null; then
    echo "Node.js could not be found. Please install node js 18 or above."
    exit 1
fi

# Verify Node.js version
version=$(node -v | cut -d'.' -f1 | tr -d 'v')
if [ "$version" -lt 18 ]; then
    echo "Invalid Node.js version. Expected 18 or above, but got $version."
    exit 1
fi
echo "Node.js version is valid."


# Install AWS CDK
echo "Installing AWS CDK..."
npm install -g aws-cdk & show_loader "Installing AWS CDK..."
echo "AWS CDK is installed successfully."

# Check for AWS CDK
if ! command -v cdk &> /dev/null; then
    echo "AWS CDK could not be found. Please rerun 'bash install.sh' with Sudo access and ensure the command is available within the \$PATH"
    exit 1
fi

# Determine OS and run respective dependency script
os=$(uname)
case "$os" in
  "Linux")
    echo "Detecting operating system: Linux"
    (bash linux_deps.sh & show_loader "Running Linux dependencies script...")
    ;;
  "Darwin")
    echo "Detecting operating system: macOS"
    (bash mac_deps.sh & show_loader "Running macOS dependencies script...")
    ;;
  *)
    echo "Unsupported operating system."
    exit 1
    ;;
esac

# Check if AWS CLI installation was successful
if ! command -v aws &> /dev/null; then
    echo "AWS CLI could not be found. Please rerun 'bash install.sh' with Sudo access and ensure the command is available within the $PATH"
    exit 1
fi

echo "Dependency installation completed."


fetch_details(){
# Trying to retrieve AWS account owner's details
if ! AWS_ACCOUNT_DETAILS_JSON=$(aws sts get-caller-identity 2>&1); then
    display_error "Unable to obtain AWS caller identity: $AWS_ACCOUNT_DETAILS_JSON"
    display_error "Check if your AWS credentials are expired and you have appropriate permissions."
    exit 1
fi

# Extracting and displaying account details
AWS_ACCOUNT_ID=$(echo "$AWS_ACCOUNT_DETAILS_JSON" | jq -r '.Account')
AWS_USER_ID=$(echo "$AWS_ACCOUNT_DETAILS_JSON" | jq -r '.UserId')
AWS_ARN=$(echo "$AWS_ACCOUNT_DETAILS_JSON" | jq -r '.Arn')
AWS_ROLE=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d '/' -f 2)
}

show_loader "Fetching AWS account details" &
fetch_details

# Waiting for the fetch_details background process to complete
wait

# Check if fetch_details exited with an error
if [ $? -ne 0 ]; then
    echo "Error fetching AWS details. Exiting script."
    exit 1
fi

# Function to print a line with padding
print_line() {
    echo "${padding}${blue}${white}$1${reset}"
}

# Displaying AWS account information in a "box"
echo "${padding}${box_line}"
echo
print_line "${bold}AWS Account Information:${reset}"
echo
print_line "Account ID: ${bold}$AWS_ACCOUNT_ID${reset}"
print_line "User ID: ${bold}$AWS_USER_ID${reset}"
print_line "Role: ${bold}$AWS_ROLE${reset}"
echo
echo "${padding}${box_line}"


echo
# Ask consent to proceed with the aws account
while true; do
    read -r -p "Do you want to proceed with the above AWS account? [y/n]: " yn
    case $yn in
        [Yy]* ) echo "Proceeding with AWS account $AWS_ACCOUNT_ID"; break;;
        [Nn]* ) echo "Exiting..."; exit;;
        * ) echo "Please answer yes or no [y/n].";;
    esac
done

# Function to display the header
echo "Checking dependencies..."

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "Node.js could not be found. Please install node js 18 or above."
    exit 1
fi

# Verify Node.js version
version=$(node -v | cut -d'.' -f1 | tr -d 'v')
if [ "$version" -lt 18 ]; then
    echo "Invalid Node.js version. Expected 18 or above, but got $version."
    exit 1
fi
echo "Node.js version is valid."

# Function to display the header
display_header() {
    print_line "###########################################"
    print_line " Welcome to Hyperswitch Services Installer"
    print_line "###########################################"
}

# Function to list available services
list_services() {
    print_line "Hyperswitch Services Available for Installation:"
    print_line "${green}1. Backend Services"
    print_line "${green}2. Demo Store"
    print_line "${green}3. Control Center"
    print_line "${green}4. Card Vault"
    print_line "${green}5. SDK"
}

INSTALLATION_MODE=1
# Function to show installation options
show_install_options() {
    echo
    echo "${bold}Choose an installation option:${reset}"
    echo "${bold}${green}1. Free Tier ${reset} - ${bold}${blue}Under Development, Stay Tuned!${reset}"
    echo "${bold}${green}2. Production Ready ${reset} - ${bold}${blue}Optimized for scalability and performance, leveraging the power of AWS EKS for robust, enterprise-grade deployments.${reset}"
}

# Function to read user input until a valid choice is made
get_user_choice() {
    while true; do
        read -r -p "Enter your choice [1-2]: " INSTALLATION_MODE
        case $INSTALLATION_MODE in
            1) echo "Free Tier option selected."; break;;
            2) echo "Production Ready option selected."; break;;
            *) echo "Invalid choice. Please enter 1 or 2.";;
        esac
    done
}

clear
display_header
echo
print_line "This installer will guide you through setting up Hyperswitch services on your AWS account."
list_services
echo
show_install_options
get_user_choice

check_if_element_is_preset_in_array() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

if [[ -z "$AWS_DEFAULT_REGION" ]]; then
    echo "Please enter the AWS region to deploy the services: "
    read -r AWS_DEFAULT_REGION
else
    echo "Please enter the AWS region to deploy the services (Press enter to keep the current region $blue$bold$AWS_DEFAULT_REGION$reset): "
    read -r input_region
    if [[ -n "$input_region" ]]; then
        AWS_DEFAULT_REGION=$input_region
    fi
fi

# Prompt for region and check if it's enabled
while true; do

  AVAILABLE_REGIONS_JSON=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text 2>&1)

  if [[ $AVAILABLE_REGIONS_JSON == *"UnauthorizedOperation"* ]]; then
    display_error "Error: Unauthorized operation. You do not have permission to perform 'ec2:DescribeRegions'."
    display_error "Contact your AWS administrator to obtain the necessary permissions."
    exit 1
  elif [[ $AVAILABLE_REGIONS_JSON == *"supported format"* ]]; then
    display_error "Error: Invalid region format. Please enter a valid region code (e.g. us-east-1)."
  else
    # Convert the region list into an array
    AVAILABLE_REGIONS=($AVAILABLE_REGIONS_JSON)

    # Check if AWS_DEFAULT_REGION is in the list of available regions
    if [[ " ${AVAILABLE_REGIONS[*]} " =~ " $AWS_DEFAULT_REGION " ]]; then
      echo "Region $AWS_DEFAULT_REGION is enabled for your account."
      break
    else
      display_error "Error: Region $AWS_DEFAULT_REGION is not enabled for your account or invalid region code."
    fi
  fi

  # Prompt for region again
  echo "Please enter the AWS region to deploy the services: "
  read -r AWS_DEFAULT_REGION

done

export LOG_FILE="cdk.services.log"
function echoLog() {
  echo "$1" | tee -a $LOG_FILE
}

echo
echo "${blue}##########################################${reset}"
echo "${blue}    Checking neccessary permissions${reset}"
echo "${blue}##########################################${reset}"
echo

check_root_user() {
  AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
  if [[ $AWS_ARN == *":root"* ]]; then
    echo "ROOT user is not recommended. Please create a new user with AdministratorAccess and use their Access Token."
    exit 1
  fi
}

REQUIRED_POLICIES=("AdministratorAccess") # Add other necessary policies to this array
# Check if the current user is a root user
echo "Verifying that you're not using the AWS root account..."
echo "(For security reasons, it's best to avoid using the root account.)"
(check_root_user) & show_loader "Verifying root user status"

check_iam_policies() {
  USER_POLICIES=$(aws iam list-attached-role-policies --role-name "$AWS_ROLE" --output json | jq -r '.AttachedPolicies[].PolicyName')
  for policy in "${REQUIRED_POLICIES[@]}"; do
    if ! echo "$USER_POLICIES" | grep -q "$policy"; then
      echo "Required policy $policy is not attached to your user. Please attach this policy."
      exit 1
    fi
  done
  echo "All necessary permissions are in place."
}

# Check for specific IAM policies
echo "Checking for necessary IAM policies..."
(check_iam_policies) & show_loader "Verifying IAM policies"

echo
echo "${blue}##########################################${reset}"
echo "${blue} Configure Credentials of the Application ${reset}"
echo "${blue}##########################################${reset}"
echo


validate_password() {
    local password=$1

    # Check length (at least 8 characters)
    if [[ ${#password} -lt 8 ]]; then
        display_error "Error: Password must be at least 8 characters."
        return 1
    fi

    # Check if it starts with an alphabet
    if [[ ! $password =~ ^[A-Za-z] ]]; then
        display_error "Error: Password must start with a letter."
        return 1
    fi

    # Check for at least one uppercase letter and one lowercase letter
    if [[ ! $password =~ [A-Z] || ! $password =~ [a-z] ]]; then
        display_error "Error: Password must include at least one uppercase and one lowercase letter."
        return 1
    fi

    # Check for at least one digit
    if [[ ! $password =~ [0-9] ]]; then
        display_error "Error: Password must include at least one digit."
        return 1
    fi

    # Check for forbidden special characters
    if [[ $password =~ [^A-Za-z0-9] ]]; then
        display_error "Error: Password cannot include special characters."
        return 1
    fi

    # read password again to confirm
    echo "Please re-enter the password: "
    read -r -s password_confirm
    if [[ "$password" != "$password_confirm" ]]; then
        display_error "Error: Passwords do not match."
        return 1
    fi

    return 0
}

# Prompt for DB Password
while true; do
    echo "Please enter the password for your RDS instance (Minimum 8 characters; includes [A-Z], [a-z], [0-9]): "
    read -r -s DB_PASS
    if validate_password "$DB_PASS"; then
        break
    fi
done
MASTER_ENC_KEY=$(openssl enc -aes-256-cbc -k secret -P -md sha1 | grep 'key' | cut -d '=' -f 2)

validate_api_key() {
    local api_key=$1

    if [[ ! $api_key =~ ^[A-Za-z0-9_]{8,}$ ]]; then
        display_error "Error: API Key must be at least 8 characters long and can include letters, numbers, and underscores."
        return 1
    fi

    # read api_key again to confirm
    echo "Please re-enter the api-key: "
    read -r -s api_key_confirm
    if [[ "$api_key" != "$api_key_confirm" ]]; then
        display_error "Error: Api Keys do not match."
        return 1
    fi
    return 0
}

# Prompt for Admin API Key
while true; do
    echo "Please enter the Admin API key (required to access Hyperswitch APIs): "
    read -r -s ADMIN_API_KEY
    if validate_api_key "$ADMIN_API_KEY"; then
        break
    fi
done


if [[ "$INSTALLATION_MODE" == 2 ]]; then

echo "Do you want to deploy the Card Vault? [y/n]: "
read -r CARD_VAULT

LOCKER=""
if [[ "$CARD_VAULT" == "y" ]]; then
  # Instructions for Card Vault Master Key
  echo "${bold}${red}If you require the Card Vault, create a master key as described below.${reset}"
  echo "${bold}${yellow}To generate the master key, use the utility at: https://github.com/juspay/hyperswitch-card-vault${reset}"
  echo "${bold}${yellow}With cargo installed, run: cargo install --git https://github.com/juspay/hyperswitch-card-vault --bin utils --root . && ./bin/utils master-key && rm ./bin/utils && rmdir ./bin${reset}"

  # Prompt for Encrypted Master Key
  echo "Enter your encrypted master key:"
  read -r -s MASTER_KEY
  LOCKER+="-c master_key=$MASTER_KEY "
  # Prompt for Locker DB Password
  while true; do
      echo "Please enter the password for your RDS instance (Minimum 8 characters; includes [A-Z], [a-z], [0-9]): "
      read -r -s LOCKER_DB_PASS
      if validate_password "$LOCKER_DB_PASS"; then
          break
      fi
  done
  LOCKER+="-c locker_pass=$LOCKER_DB_PASS "
fi

echo "${blue}#########################################${reset}"
echo "${blue}      Deploying Hyperswitch Services${reset}"
echo "${blue}#########################################${reset}"
# Deploy the EKS Cluster
npm install
export JSII_SILENCE_WARNING_UNTESTED_NODE_VERSION=true
if ! cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN; then
    BUCKET_NAME=cdk-hnb659fds-assets-$AWS_ACCOUNT_ID-$AWS_DEFAULT_REGION
    aws s3 rm s3://$BUCKET_NAME --recursive 
    aws s3api delete-bucket --bucket $BUCKET_NAME
    cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN
fi
if cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN -c master_enc_key=$MASTER_ENC_KEY $LOCKER ; then
  # Wait for the EKS Cluster to be deployed
  echo `aws eks create-addon --cluster-name hs-eks-cluster --addon-name amazon-cloudwatch-observability`
  aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name hs-eks-cluster
  # Deploy Load balancer and Ingress
  echo "##########################################"
  sleep 10
  APP_HOST=$(kubectl get ingress hyperswitch -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  LOGS_HOST=$(kubectl get ingress hyperswitch-logs -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  CONTROL_CENTER_HOST=$(kubectl get ingress hyperswitch-control-center -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  SDK_WEB_HOST=$(kubectl get ingress hyperswitch-web -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  SDK_HOST=$(kubectl get ingress hyperswitch-sdk-demo -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
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
  printf "##########################################\nPlease wait for the application to deploy - Avg Wait time: ~4 mins\n##########################################"
  helm get values -n hyperswitch hypers-v1 > values.yaml
  helm upgrade --install hypers-v1 hs/hyperswitch-helm --set "application.dashboard.env.apiBaseUrl=http://$APP_HOST,application.sdk.env.hyperswitchPublishableKey=$PUB_KEY,application.sdk.env.hyperswitchSecretKey=$API_KEY,application.sdk.env.hyperswitchServerUrl=http://$APP_HOST,application.sdk.env.hyperSwitchClientUrl=$SDK_URL,application.dashboard.env.sdkBaseUrl=$SDK_URL/HyperLoader.js,application.server.server_base_url=http://$APP_HOST,hyperswitchsdk.autoBuild.buildParam.envSdkUrl=http://$SDK_WEB_HOST,hyperswitchsdk.autoBuild.buildParam.envBackendUrl=http://$APP_HOST" -n hyperswitch -f values.yaml
  sleep 240
  echoLog "--------------------------------------------------------------------------------"
  echoLog "$bold Service                           Host$reset"
  echoLog "--------------------------------------------------------------------------------"
  echoLog "$green HyperloaderJS Hosted at           $blue"$SDK_URL/HyperLoader.js"$reset"
  echoLog "$green App server running on             $blue"http://$APP_HOST"$reset"
  echoLog "$green Logs server running on            $blue"http://$LOGS_HOST"$reset, Login with $YELLOW username: admin, password: admin$reset , Please change on startup"
  echoLog "$green Control center server running on  $blue"http://$CONTROL_CENTER_HOST"$reset, Login with $YELLOW Email: test@gmail.com, password: admin$reset , Please change on startup"
  echoLog "$green Hyperswitch Demo Store running on $blue"http://$SDK_HOST"$reset"
  echoLog "--------------------------------------------------------------------------------"
  echoLog "##########################################"
  echo "$blue Please run 'cat cdk.services.log' to view the services details again"$reset
  exit 0
else
  echo "Deleting cloud formation. Please re-run 'sh install.sh'"
  aws cloudformation delete-stack --stack-name CDKToolkit
fi

else

echo "${blue}#########################################${reset}"
echo "${blue}      Deploying Hyperswitch Services${reset}"
echo "${blue}#########################################${reset}"
echo
echo "Hyperswitch is being deployed in standalone mode. Please wait for the deployment to complete."

npm install
cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN
if cdk deploy --require-approval never -c test=true ; then
  STANDALONE_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='StandaloneUrl'].OutputValue" --output text)
  echoLog "--------------------------------------------------------------------------------"
  echoLog "$bold EC2 Instance IP Host                          $blue"$STANDALONE_HOST"$reset"
  echoLog "--------------------------------------------------------------------------------"
else
  aws cloudformation delete-stack --stack-name CDKToolkit
fi
fi
