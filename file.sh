export APP_HOST=$(kubectl get ingress hyperswitch-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export LOGS_HOST=$(kubectl get ingress hyperswitch-logs-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export CONTROL_CENTER_HOST=$(kubectl get ingress hyperswitch-control-center-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export SDK_HOST=$(kubectl get ingress hyperswitch-sdk-alb-ingress -n hyperswitch -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export REDIS_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='RedisHost'].OutputValue" --output text)
export DB_HOST=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='DbHost'].OutputValue" --output text)
export LB_SG=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='LbSecurityGroupId'].OutputValue" --output text)
export SDK_URL=$(aws cloudformation describe-stacks --stack-name hyperswitch --query "Stacks[0].Outputs[?OutputKey=='HyperLoaderUrl'].OutputValue" --output text)
export SDK_IMAGE="jeevaramachandran/hyperswitch-web:v1.0.0"
