#!/bin/bash
# shellcheck disable=2155


source deps.sh

set -e

ask_yes_no() {
    local prompt="$1 [y/n]: "
    local response

    read -r -p "$prompt" response

    case "$response" in
        [yY]|[yY][eE][sS])
            return 0  # Yes
            ;;
        [nN]|[nN][oO])
            return 1  # No
            ;;
        *)
            echo "Invalid input. Please enter 'y' or 'n'."
            ask_yes_no "$1"  # Ask again
            ;;
    esac
}


AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
if [[ $AWS_ARN == *":root"* ]]; then
    echo "ROOT user is not recommended. Please create new user with AdministratorAccess and use their Access Token"
    exit 1
fi
echo "##########################################"

echo "$(tput bold)$(tput setaf 2)Install Locker Standalone Setup$(tput sgr0)"


echo "$(tput bold)$(tput setaf 3)Please make sure that the following environment variables are set properly:"
echo "- AWS_DEFAULT_REGION"
echo "- AWS_PROFILE$(tput sgr0)"

if ! ask_yes_no "Continue with the installation?"; then
    exit 1
fi


echo "$(tput bold)$(tput setaf 3)The VPC ID is optional, if absent a VPC will be created for this standalone deployment$(tput sgr0)"
read -r -p "Enter the VPC ID to use (optional): " VPC_ID

if [[ -n "$VPC_ID" ]]; then
    LOCKER_FLAGS="-c vpc_id=$VPC_ID "

    echo "$(tput bold)$(tput setaf 3)The following Subnet IDs are optional and can be skipped in case:$(tput sgr0)"
    echo "$(tput bold)$(tput setaf 3)- You have a private subnet with egress$(tput sgr0)"
    echo "$(tput bold)$(tput setaf 3)- You don't want to manually configure$(tput sgr0)"
    echo
    echo "$(tput bold)$(tput setaf 3)Otherwise, the input format for the subnet ids is <subnet-id>,<availability-zone> (e.g. subnet-00000000000000000,us-east-1a)$(tput sgr0)"

    read -r -p "Enter the Locker Subnet ID to use (optional): " LOCKER_SUBNET_ID

    if [ -n "$LOCKER_SUBNET_ID" ]; then
        LOCKER_FLAGS+="-c locker_subnet_id=$LOCKER_SUBNET_ID "
    fi

    echo "$(tput bold)$(tput setaf 3)In case of database please provide 2 subnets with different availability zones,"
    echo "(e.g. subnet-00000000000000000,us-east-1a,subnet-11111111111111111,us-east-1b)$(tput sgr0)"
    read -r -p "Enter the Locker DB Subnet ID to use (optional): " LOCKER_DB_SUBNET_ID


    if [ -n "$LOCKER_DB_SUBNET_ID" ]; then
        LOCKER_FLAGS+="-c locker_db_subnet_id=$LOCKER_DB_SUBNET_ID "
    fi

fi


echo "$(tput bold)$(tput setaf 3)To generated the master key, you can use the utility bundled within \n(https://github.com/juspay/hyperswitch-card-vault)$(tput sgr0)"
echo "$(tput bold)$(tput setaf 3)If you have cargo installed you can run \n(cargo install --git https://github.com/juspay/hyperswitch-card-vault --bin utils --root . && ./bin/utils master-key && rm ./bin/utils && rmdir ./bin)$(tput sgr0)"

read -r -s -p "Enter the generated master key: " MASTER_KEY

echo

read -r -s -p "Enter the database password to be used: " DB_PASS

echo

if ask_yes_no "Should we include a jump server in the installation?"; then
    JUMP_SERVER="true"
else
    JUMP_SERVER="false"
fi

export TEMP_FILE=$(mktemp)

export STACK="card-vault"


AWS_ACCOUNT=$(aws sts get-caller-identity --output json | jq -r .Account)
cdk bootstrap aws://"$AWS_ACCOUNT"/"$AWS_DEFAULT_REGION" -c aws_arn="$AWS_ARN"

cdk deploy --require-approval never -c master_key="$MASTER_KEY" -c db_pass="$DB_PASS" -c stack="card-vault" -c locker_jump=$JUMP_SERVER $LOCKER_FLAGS  > "$TEMP_FILE"

export JUMP_COMMAND=$(grep 'GetJumpLockerSSHKey' < "$TEMP_FILE" | sed 's/.*GetJumpLockerSSHKey = \(.*\)/\1/g')

export JUMP_IP=$(grep 'JumpLockerPublicIP' < "$TEMP_FILE" | sed 's/.*JumpLockerPublicIP = \(.*\)/\1/g')

export LOCKER_COMMAND=$(grep 'GetLockerSSHKey' < "$TEMP_FILE" | sed 's/.*GetLockerSSHKey.* = \(.*\)/\1/g')

export LOCKER_IP=$(grep 'LockerIP' < "$TEMP_FILE"| sed 's/.*LockerIP.* = \(.*\)/\1/g')


echo "
$JUMP_COMMAND
$LOCKER_COMMAND
chmod 400 locker-jump.pem

ssh -i locker-jump.pem ec2-user@$JUMP_IP


unset HISTFILE

curl -X 'POST' '$LOCKER_IP:8080/custodian/key1' -H 'Content-Type: application/json' --data '{ \"key\": \"<ENTER_YOUR_KEY1_HERE>\" }'
curl -X 'POST' '$LOCKER_IP:8080/custodian/key2' -H 'Content-Type: application/json' --data '{ \"key\": \"<ENTER_YOUR_KEY2_HERE>\" }'
curl -X 'POST' '$LOCKER_IP:8080/custodian/decrypt'

curl -X 'POST' '$LOCKER_IP:8080/health'
"

echo

echo "$(tput bold)$(tput setaf 2)Please run (docker ps) to view if the container is running and healthy"
echo "and then check docker logs for any errors$(tput sgr0)"
