mkdir tmp
cd tmp
echo "Fetching the external and internal jump box IPs"
export EXTERNAL_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=hyperswitch/hyperswitch_external_jump_ec2" --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

aws ssm get-parameter --name /ec2/keypair/$(aws ec2 describe-key-pairs --filters Name=key-name,Values="hyperswitch_external_jump_ec2-keypair" --query "KeyPairs[*].KeyPairId" --output text) --with-decryption --query Parameter.Value --output text > external_jump.pem
aws ssm get-parameter --name /ec2/keypair/$(aws ec2 describe-key-pairs --filters Name=key-name,Values="hyperswitch_internal_jump_ec2-keypair" --query "KeyPairs[*].KeyPairId" --output text) --with-decryption --query Parameter.Value --output text > internal_jump.pem
aws ssm get-parameter --name /ec2/keypair/$(aws ec2 describe-key-pairs --filters Name=key-name,Values="Locker-ec2-keypair" --query "KeyPairs[*].KeyPairId" --output text) --with-decryption --query Parameter.Value --output text > locker.pem

chmod 400 external_jump.pem

scp -i external_jump.pem internal_jump.pem ec2-user@$EXTERNAL_IP:/home/ec2-user/internal_jump.pem
scp -i external_jump.pem locker.pem ec2-user@$EXTERNAL_IP:/home/ec2-user/locker.pem

export INTERNAL_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=hyperswitch/hyperswitch_internal_jump_ec2" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)
export LOCKER_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=hyperswitch/LockerSetup/LockerEc2/locker-ec2" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)

cat << EOF2 > external_jump.sh
#!/bin/sh
export INTERNAL_IP=$INTERNAL_IP
export LOCKER_IP=$LOCKER_IP
chmod 400 internal_jump.pem
scp -i internal_jump.pem locker.pem ec2-user@$INTERNAL_IP:/home/ec2-user/locker.pem

cat << EOF1 > internal_jump.sh
#!/bin/sh

chmod 400 locker.pem

cat << EOF > locker-inner.sh
#!/bin/sh
 echo "Please enter the keys that are created during the locker master key generation"   
 echo "Enter the key1"
 read -s KEY1
 curl -X 'POST' 'localhost:8080/custodian/key1' -H 'Content-Type: application/json' -d '{ "key": "'\\\\\\\$KEY1'" }'

 echo 
 echo "Enter the key2"
 read -s KEY2
 curl -X 'POST' 'localhost:8080/custodian/key2' -H 'Content-Type: application/json' -d '{ "key": "'\\\\\\\$KEY2'" }'

 echo 
 curl -X 'POST' 'localhost:8080/custodian/decrypt'
 echo 
EOF


scp -i locker.pem ./locker-inner.sh ec2-user@$LOCKER_IP:/home/ec2-user/unlock_locker.sh

ssh -i locker.pem ec2-user@$LOCKER_IP
EOF1

scp -i internal_jump.pem ./internal_jump.sh ec2-user@$INTERNAL_IP:/home/ec2-user/internal_jump.sh

ssh -t -i internal_jump.pem ec2-user@$INTERNAL_IP


EOF2

scp -i ./external_jump.pem ./external_jump.sh ec2-user@$EXTERNAL_IP:/home/ec2-user/external_jump.sh
ssh -i external_jump.pem ec2-user@$EXTERNAL_IP
cd ..