#! /usr/bin/env bash

# Setting up color and style variables
bold=$(tput bold)
blue=$(tput setaf 4)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0)
source ./bash/utils.sh

# Function to display error messages in red
display_error() {
    echo "${bold}${red}$1${reset}"
}

# Checking for AWS credentials
if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_SESSION_TOKEN" ]]; then
    display_error "Missing AWS credentials. Please configure the AWS CLI with your credentials."
    exit 1
fi

function box_out() {
    local s=("$@") b w padding terminalWidth
    for l in "${s[@]}"; do
        ((w < ${#l})) && {
            b="$l"
            w="${#l}"
        }
    done
    terminalWidth=$(tput cols)               # Get the terminal width
    padding=$(((terminalWidth - w - 4) / 2)) # Calculate padding; subtract 4 for the box borders

    tput bold
    tput setaf 2
    printf "%*s" $padding "" # Add padding before the top line
    echo " ${b//?/ } "
    for l in "${s[@]}"; do
        printf "%*s" $padding "" # Add padding before each line within the box
        printf " %s%*s%s " "$(tput sgr 0)$(tput bold)" "-$w" "$l" "$(tput bold)$(tput setaf 2)"
        echo # New line
    done
    tput sgr 0
}

function box_out_with_hyphen() {
    local s=("$@") b w padding terminalWidth
    for l in "${s[@]}"; do
        ((w < ${#l})) && {
            b="$l"
            w="${#l}"
        }
    done
    terminalWidth=$(tput cols)               # Get the terminal width
    padding=$(((terminalWidth - w - 4) / 2)) # Calculate padding; subtract 4 for the box borders

    tput bold
    tput setaf 2
    printf "%*s" $padding "" # Add padding before the top line
    echo " -${b//?/-}-"
    printf "%*s" $padding "" # Add padding before the second line
    echo "| ${b//?/ } |"
    for l in "${s[@]}"; do
        printf "%*s" $padding "" # Add padding before each line within the box
        printf "| %s%*s%s |" "$(tput sgr 0)$(tput bold)" "-$w" "$l" "$(tput bold)$(tput setaf 2)"
        echo # New line
    done
    printf "%*s" $padding "" # Add padding before the bottom second line
    echo "| ${b//?/ } |"
    printf "%*s" $padding "" # Add padding before the bottom line
    echo " -${b//?/-}-"
    tput sgr 0
}
bash ./bash/deps.sh
echo "Dependency installation completed."

fetch_details() {
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

# Displaying AWS account information in a "box"
echo
box_out_with_hyphen "AWS Account Information:" "" "Account ID: $AWS_ACCOUNT_ID" "User ID: $AWS_USER_ID" "Role: $AWS_ROLE"
echo
# Ask consent to proceed with the aws account
while true; do
    read -r -p "Do you want to proceed with the above AWS account? [y/n]: " yn
    case $yn in
    [Yy]*)
        echo "Proceeding with AWS account $AWS_ACCOUNT_ID"
        break
        ;;
    [Nn]*)
        echo "Exiting..."
        exit
        ;;
    *) echo "Please answer yes or no [y/n]." ;;
    esac
done

# Function to display the header
echo "Checking dependencies..."

# Check for Node.js
if ! command -v node &>/dev/null; then
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

# Function to list available services
list_services() {
    box_out_with_hyphen "   Welcome to Hyperswitch Services Installer" "" "" "Hyperswitch Services Available for Installation:" "              1. Backend Services" "              2. Demo Store" "              3. Control Center" "              4. Card Vault" "              5. SDK"
}

INSTALLATION_MODE=1
# Function to show installation options
show_install_options() {
    echo
    echo "${bold}Choose an installation option:${reset}"
    echo "${bold}${green}1. Free Tier ${reset} - ${bold}${blue}Only for prototyping and not scalable. Falls under AWS Free Tier. ${reset}"
    echo "${bold}${green}2. Production Ready ${reset} - ${bold}${blue}Optimized for scalability and performance, leveraging the power of AWS EKS for robust, enterprise-grade deployments.${reset}"
}

# declare base_ami,envoy_ami,squid_ami

# check_image_builder() {
#     ssm=$(aws ssm get-parameters \
#             --names base_image_ami squid_image_ami envoy_image_ami \
#             --query "Parameters[*].{Name:Name,Value:Value}" --output json)

#     length=$(echo "$ssm" | jq -r ".|length")

#     if [ "$length" -lt 3 ]; then
#         display_error "Unable to find base images for Proxy Servers. Please run the following command: bash deploy_imagebuilder.sh\nIf you have done it already please wait for 15-20 mins until it builds the images"
#         exit 1
#     fi

#     base_ami=$(echo "$ssm" | jq '.[]|select(.Name=="base_image_ami")|.Value')
#     envoy_ami=$(echo "$ssm" | jq '.[]|select(.Name=="envoy_image_ami")|.Value')
#     squid_ami=$(echo "$ssm" | jq '.[]|select(.Name=="squid_image_ami")|.Value')

# }

# Function to read user input until a valid choice is made
get_user_choice() {
    while true; do
        read -r -p "Enter your choice [1-2]: " INSTALLATION_MODE
        case $INSTALLATION_MODE in
        1)
            echo "Free Tier option selected."
            break
            ;;
        2)
            echo "Production Ready option selected."
            break
            ;;
        *) echo "Invalid choice. Please enter 1 or 2." ;;
        esac
    done
}

clear
list_services
echo
# check_image_builder
show_install_options
get_user_choice

check_if_element_is_preset_in_array() {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

if [[ -z "$AWS_DEFAULT_REGION" ]]; then
    read -p "Please enter the AWS region to deploy the services: " AWS_DEFAULT_REGION
else
    read -p "Please enter the AWS region to deploy the services (Press enter to keep the current region $blue$bold$AWS_DEFAULT_REGION$reset): " input_region
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
    read -p "Please enter the AWS region to deploy the services: " AWS_DEFAULT_REGION

done

export AWS_DEFAULT_REGION;

echo
printf "${bold}Checking neccessary permissions${reset}\n"
echo

check_root_user() {
    AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn)
    if [[ $AWS_ARN == *":root"* ]]; then
        echo "ROOT user is not recommended. Please create a new user with AdministratorAccess and use their Access Token."
        exit 1
    fi
}

REQUIRED_POLICIES=("AdministratorAccess") # Add other necessary policies to this array
# Check if the current user is a root user
echo "Verifying that you're not using the AWS root account..."
echo "(For security reasons, it's best to avoid using the root account.)"
(check_root_user) &
show_loader "Verifying root user status"

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
(check_iam_policies) &
show_loader "Verifying IAM policies"

echo
printf "${bold}Configure Credentials of the Application${reset}\n"
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

    while true; do
        echo "Please enter the AES master encryption key. It must be 64 characters long and consist of hexadecimal digits:"
        echo "${bold}${red}Please create the AES master encryption key as described below.${reset}"
        echo "${bold}${yellow}To generate the master key, run the following command: openssl enc -aes-256-cbc -k secret -P -md sha1${reset}"
        echo "${bold}${yellow}Copy the value of 'key' from the output and use it as the master key.${reset}"
        read -r -s MASTER_ENC_KEY
        if [[ ${#MASTER_ENC_KEY} -eq 64 && $MASTER_ENC_KEY =~ ^[0-9a-fA-F]+$ ]]; then
            break
        else
            display_error "Invalid input. The master encryption key must be 64 characters long and consist of hexadecimal digits."
        fi
    done

    echo "Please enter the IP addresses that you want to whitelist for the EKS cluster. If you have multiple IP addresses, separate them with commas. If you want to use the default value, simply press enter."
    read -r VPN_IPS

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
            breakup
            fi
        done
        LOCKER+="-c locker_pass=$LOCKER_DB_PASS "
    fi

    printf "${bold}Deploying Hyperswitch Services${reset}\n"
    # Deploy the EKS Cluster
    npm install
    export JSII_SILENCE_WARNING_UNTESTED_NODE_VERSION=true
    if ! cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN; then
        BUCKET_NAME=cdk-hnb659fds-assets-$AWS_ACCOUNT_ID-$AWS_DEFAULT_REGION
        ROLE_NAME=cdk-hnb659fds-cfn-exec-role-$AWS_ACCOUNT_ID-$AWS_DEFAULT_REGION
        aws s3api delete-objects --bucket $BUCKET_NAME --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null
        aws s3api delete-objects --bucket $BUCKET_NAME --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null
        aws s3 rm s3://$BUCKET_NAME --recursive 2>/dev/null
        aws s3api delete-bucket --bucket $BUCKET_NAME 2>/dev/null
        for policy_arn in $(aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[].PolicyArn' --output text); do
            aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $policy_arn 2>/dev/null
        done
        aws iam delete-role --role-name $ROLE_NAME 2>/dev/null
        cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN
    fi
    if cdk deploy --require-approval never -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY -c aws_arn=$AWS_ARN -c master_enc_key=$MASTER_ENC_KEY -c vpn_ips=$VPN_IPS -c base_ami=$base_ami -c envoy_ami=$envoy_ami -c squid_ami=$squid_ami $LOCKER; then
        # Wait for the EKS Cluster to be deployed
        echo $(aws eks create-addon --cluster-name hs-eks-cluster --addon-name amazon-cloudwatch-observability)
        aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name hs-eks-cluster
        helm get values -n hyperswitch hypers-v1 > values.yaml
        sh upgrade.sh "$ADMIN_API_KEY" "$CARD_VAULT"
        exit 0
    fi

else
    echo
    printf "${bold}Deploying Hyperswitch Services${reset}\n"
    echo
    echo "Hyperswitch is being deployed in standalone mode. Please wait for the deployment to complete."

    npm install
    if ! cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN; then
        BUCKET_NAME=cdk-hnb659fds-assets-$AWS_ACCOUNT_ID-$AWS_DEFAULT_REGION
        ROLE_NAME=cdk-hnb659fds-cfn-exec-role-$AWS_ACCOUNT_ID-$AWS_DEFAULT_REGION
        aws s3api delete-objects --bucket $BUCKET_NAME --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null
        aws s3api delete-objects --bucket $BUCKET_NAME --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null
        aws s3 rm s3://$BUCKET_NAME --recursive 2>/dev/null
        aws s3api delete-bucket --bucket $BUCKET_NAME 2>/dev/null
        for policy_arn in $(aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[].PolicyArn' --output text); do
            aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $policy_arn 2>/dev/null
        done
        aws iam delete-role --role-name $ROLE_NAME 2>/dev/null
        cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_DEFAULT_REGION -c aws_arn=$AWS_ARN
    fi
    if cdk deploy -c aws_arn=$AWS_ARN -c free_tier=true -c db_pass=$DB_PASS -c admin_api_key=$ADMIN_API_KEY; then
        STANDALONE_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='StandaloneURL'].OutputValue" --output text)
        CONTROL_CENTER_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='ControlCenterURL'].OutputValue" --output text)
        SDK_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='SdkAssetsURL'].OutputValue" --output text)
        DEMO_APP=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='DemoApp'].OutputValue" --output text)
        echo "Please wait for instances to be initialized. Approximate time is 2 minutes."
        printf "${bold}Initializing Instances${reset} "
        # Start the spinner in the background
        (
            while :; do
                for s in '/' '-' '\\' '|'; do
                    printf "\r$s"
                    sleep 1
                done
            done
        ) &
        spinner_pid=$!
        # Sleep for 10 seconds to simulate work
        sleep 60
        # Kill the spinner
        kill $spinner_pid >/dev/null 2>&1
        wait $spinner_pid 2>/dev/null # Ensures the spinner process is properly terminated before moving on
        printf "\r"                   # Clear the spinner character
        printf "\nInitialization complete.\n"
        printf "\n"
        echoLog "--------------------------------------------------------------------------------"
        echoLog "$bold Service                           Host$reset"
        echoLog "--------------------------------------------------------------------------------"
        echoLog "$green Standalone Hosted at             $blue"$STANDALONE_HOST"$reset"
        echoLog "$green Control center server running on  $blue"$CONTROL_CENTER_HOST"$reset"
        echoLog "$green SDK Hosted at                    $blue"$SDK_HOST"$reset"
        echoLog "$green Hyperswitch Demo Store running on $blue"$DEMO_APP"$reset"
        echoLog "--------------------------------------------------------------------------------"
    fi
fi
