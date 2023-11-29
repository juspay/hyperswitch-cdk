#!/bin/bash
# shellcheck disable=2155


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

echo -e "$(tput bold)$(tput setaf 2)Install Locker Standalone Setup$(tput sgr0)"

read -p "Enter the VPC ID to use: " VPC_ID

echo -e "$(tput bold)$(tput setaf 3)To generated the master key, you can use the utility bundled within \n(https://github.com/juspay/hyperswitch-card-vault)$(tput sgr0)"
echo -e "$(tput bold)$(tput setaf 3)If you have cargo installed you can run \n(cargo install --git https://github.com/juspay/hyperswitch-card-vault --bin utils --root . && utils master-key && rm ./bin/utils && rmdir ./bin)$(tput sgr0)"

read -r -s -p "Enter the generated master key: " MASTER_KEY

echo

read -r -s -p "Enter the database password to be used: " DB_PASS

echo

echo -e "$(tput bold)$(tput setaf 3)Please make sure that the following environment variables are set properly:- AWS_DEFAULT_REGION\n- AWS_PROFILE$(tput sgr0)"

if ! ask_yes_no "Continue with the installation?"; then
    exit 1
fi

if ask_yes_no "Should we include a jump server in the installation?"; then
    JUMP_SERVER="true"
else
    JUMP_SERVER="false"
fi

export TEMP_FILE=$(mktemp)

export STACK="card-vault"

cdk deploy --require-approval never -c vpc_id="$VPC_ID" -c master_key="$MASTER_KEY" -c db_pass="$DB_PASS" -c stack="card-vault" -c locker_jump=$JUMP_SERVER > "$TEMP_FILE"


export JUMP_COMMAND=$(grep ''$STACK'.GetJumpLockerSSHKey' < "$TEMP_FILE" | sed 's/'$STACK'.GetJumpLockerSSHKey = \(.*\)/\1/g')

export JUMP_IP=$(grep ''$STACK'.JumpLockerPublicIP' < "$TEMP_FILE" | sed 's/'$STACK'.JumpLockerPublicIP = \(.*\)/\1/g')

export LOCKER_COMMAND=$(grep ''$STACK'.GetLockerSSHKey' < "$TEMP_FILE" | sed 's/'$STACK'.GetLockerSSHKey = \(.*\)/\1/g')

export LOCKER_IP=$(grep ''$STACK'.Lockerec2IP' < "$TEMP_FILE"| sed 's/'$STACK'.Lockerec2IP = \(.*\)/\1/g')


echo "
$JUMP_COMMAND
chmod 400 locker-jump.pem
$LOCKER_COMMAND

scp -i locker-jump.pem ./locker.pem ec2-user@$JUMP_IP:/home/ec2-user/locker.pem
ssh -i locker-jump.pem ec2-user@JUMP_IP 'bash -c \"echo export LOCKER_IP=$LOCKER_IP >> /home/ec2-user/.bashrc && chmod 400 /home/ec2-user/locker.pem\"'
ssh -i locker-jump.pem ec2-user@$JUMP_IP

ssh -i locker.pem ec2-user@\$LOCKER_IP

unset HISTFILE

curl -X 'POST' 'localhost:8080/custodian/key1' -H 'Content-Type: application/json' --data '{ \"key\": \"<ENTER_YOUR_KEY1_HERE>\" }'
curl -X 'POST' 'localhost:8080/custodian/key2' -H 'Content-Type: application/json' --data '{ \"key\": \"<ENTER_YOUR_KEY2_HERE>\" }'
curl -X 'POST' 'localhost:8080/custodian/decrypt'
"

echo

echo "$(tput bold)$(tput setaf 2)Please run (docker ps) to view if the container is running and healthy"
echo "and then check docker logs for any errors$(tput sgr0)"
