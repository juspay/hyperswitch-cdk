import boto3
import logging
import json
import traceback

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def find_alb_by_namespace():
    """
    Find the ALB by matching its name with expected namespace patterns.
    """
    elbv2 = boto3.client('elbv2')

    # Get all load balancers
    response = elbv2.describe_load_balancers()
    load_balancers = response.get('LoadBalancers', [])
    logger.info(f"Found {len(load_balancers)} load balancers")

    # The expected naming patterns for AWS Load Balancer Controller
    k8s_prefix = 'k8s-'
    namespace_patterns = ['hyperswitchistioa', 'hyperswitchistio', 'istiosystem']

    # Look for ALBs matching the naming pattern
    for lb in load_balancers:
        lb_name = lb['LoadBalancerName']
        if lb_name.startswith(k8s_prefix):
            for pattern in namespace_patterns:
                if lb_name.startswith(k8s_prefix + pattern):
                    logger.info(f"Found ALB by name pattern: {lb_name}")
                    return lb['DNSName']
    
    # If not found
    logger.warning("No ALB found matching expected namespace patterns")
    return None

def handler(event, context):
    """
    Lambda function to find the DNS name of the Istio ALB created by AWS Load Balancer Controller.
    """
    logger.info(f"Lambda invoked with event: {json.dumps(event)}")

    try:
        dns_name = find_alb_by_namespace()

        if dns_name:
            result = {'DnsName': dns_name}
        else:
            result = {'DnsName': 'istio-alb-not-found.example.com'}

        logger.info(f"Lambda response: {json.dumps(result)}")
        return result

    except Exception as e:
        logger.error(f"Error finding ALB: {str(e)}")
        logger.error(traceback.format_exc())
        return {
            'DnsName': f'error-{str(e)[:50]}'
        }