AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
bun cdk destroy --require-approval never -c aws_arn=$AWS_ARN