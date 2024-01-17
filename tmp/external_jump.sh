#!/bin/sh
export INTERNAL_IP=10.0.0.45
export LOCKER_IP=10.0.2.148
chmod 400 internal_jump.pem
scp -i internal_jump.pem locker.pem ec2-user@10.0.0.45:/home/ec2-user/locker.pem

cat << EOF1 > internal_jump.sh
#!/bin/sh

chmod 400 locker.pem

cat << EOF > locker-inner.sh
#!/bin/sh
 echo "Please enter the keys that are created during the locker master key generation"   
 echo "Enter the key1"
 read -s KEY1
 curl -X 'POST' 'localhost:8080/custodian/key1' -H 'Content-Type: application/json' -d '{ "key": "'\\\$KEY1'" }'

 echo 
 echo "Enter the key2"
 read -s KEY2
 curl -X 'POST' 'localhost:8080/custodian/key2' -H 'Content-Type: application/json' -d '{ "key": "'\\\$KEY2'" }'

 echo 
 curl -X 'POST' 'localhost:8080/custodian/decrypt'
 echo 
EOF


scp -i locker.pem ./locker-inner.sh ec2-user@10.0.2.148:/home/ec2-user/unlock_locker.sh

ssh -i locker.pem ec2-user@10.0.2.148
EOF1

scp -i internal_jump.pem ./internal_jump.sh ec2-user@10.0.0.45:/home/ec2-user/internal_jump.sh

ssh -t -i internal_jump.pem ec2-user@10.0.0.45


