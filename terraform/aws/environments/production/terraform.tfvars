aws_region  = "us-west-2"
stack_name  = "tf-hypers-prod"
environment = "production"

vpc_cidr = "10.0.0.0/16"
az_count = 2

admin_api_key      = "test_admin"
db_name            = "hyperswitch"
db_user            = "db_user"
db_password        = "db_password"
jwt_secret         = "jwt_secret"
master_key         = "2222FD55CEFB1F530566DBED278B0CF59D5CA77DE860F2BC755087CD596A1D42"
locker_enabled     = false
locker_public_key  = "locker_public_key"
tenant_private_key = "tenant_private_key"

envoy_image_ami = "ami-0e7e13943ad361ac7"
squid_image_ami = "ami-01fe81669ea5235b7"
