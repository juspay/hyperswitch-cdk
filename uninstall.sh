#! /usr/bin/env bash

# Setting up color and style variables
bold=$(tput bold)
blue=$(tput setaf 4)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0)

# Function to display error messages in red
display_error() {
    echo "${bold}${red}$1${reset}"
}

# Checking for AWS credentials
if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_SESSION_TOKEN" ]]; then
    display_error "Missing AWS credentials. Please configure the AWS CLI with your credentials."
    exit 1
fi

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

fetch_details

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

# check if AWS DEFAULT REGION in the environment variables and prompt accordingly.
if [[ -z "$AWS_DEFAULT_REGION" ]]; then
    read -p "Please enter the AWS region to destroy the Hyperswitch stack: " AWS_DEFAULT_REGION
else
    read -p "Please enter the AWS region to destroy the Hyperswitch stack (Press enter to keep the current region $blue$bold$AWS_DEFAULT_REGION$reset): " input_region
    if [[ -n "$input_region" ]]; then
        AWS_DEFAULT_REGION=$input_region
    fi
fi

export AWS_DEFAULT_REGION;

# delete the load balancers created by the ingress. names: hyperswitch, hyperswitch-sdk-demo, hyperswitch-control-center, hyperswitch-web, hyperswitch-logs
load_balancers=("hyperswitch" "hyperswitch-sdk-demo" "hyperswitch-control-center" "hyperswitch-web" "hyperswitch-logs")

# Loop over each load balancer
for lb in "${load_balancers[@]}"; do
  # Get the ARN of the load balancer
  lb_arn=$(aws elbv2 describe-load-balancers --names $lb --query 'LoadBalancers[0].LoadBalancerArn' --output text)

  # Delete the load balancer
  aws elbv2 delete-load-balancer --load-balancer-arn $lb_arn
done

# destroy the stack
AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
cdk destroy --require-approval never -c aws_arn=$AWS_ARN --force