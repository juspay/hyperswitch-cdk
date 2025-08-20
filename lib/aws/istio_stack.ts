import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import { KubectlV32Layer } from '@aws-cdk/lambda-layer-kubectl-v32';
import { SecurityGroups } from './security_groups';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as cr from 'aws-cdk-lib/custom-resources';
import * as path from 'path';

export interface IstioResourcesProps { 
  cluster?: eks.Cluster; 
  vpc: ec2.IVpc;
  securityGroups: SecurityGroups; 
  clusterName?: string; 
  kubectlRoleArn?: string; 
}

export class IstioResources extends Construct { 
  public readonly istioInternalAlbDnsName: string;
  public readonly trafficControlChart: eks.HelmChart; 
  public readonly istioInternalLbSecurityGroup: ec2.ISecurityGroup;

  constructor(scope: Construct, id: string, props: IstioResourcesProps) { 
    super(scope, id); 

    const privateEcrRepository = `${process.env.CDK_DEFAULT_ACCOUNT}.dkr.ecr.${process.env.CDK_DEFAULT_REGION}.amazonaws.com`;

    const istioInternalLbSg = props.securityGroups.istioInternalLbSecurityGroup;

    this.istioInternalLbSecurityGroup = istioInternalLbSg;

    let cluster: eks.Cluster;
    
    if (props.cluster) {

      cluster = props.cluster;
      
    } else if (props.clusterName && props.kubectlRoleArn) {
      let kubectlRoleArn = props.kubectlRoleArn;
      
      if (kubectlRoleArn.includes(':assumed-role/')) {
        const parts = kubectlRoleArn.split('/');
        const roleName = parts[1];
        const accountId = kubectlRoleArn.split(':')[4];
        kubectlRoleArn = `arn:aws:iam::${accountId}:role/${roleName}`;
      }
      
      cluster = eks.Cluster.fromClusterAttributes(scope, 'ImportedClusterForIstio', {
        clusterName: props.clusterName,
        vpc: props.vpc,
        kubectlRoleArn: kubectlRoleArn,
        kubectlLayer: new KubectlV32Layer(scope, 'IstioKubectlLayer'), 
      }) as eks.Cluster;
    } else {
      throw new Error('Either cluster or both clusterName and kubectlRoleArn must be provided');
    }

    const istioBase = cluster.addHelmChart('IstioBase', {
      chart: 'base',
      repository: 'https://istio-release.storage.googleapis.com/charts',
      namespace: 'istio-system',
      release: 'istio-base',
      version: '1.25.0', 
      values: {
        defaultRevision: 'default',
      },
      createNamespace: true,
      wait: true,
    });

    const istiod = cluster.addHelmChart('Istiod', { 
      chart: 'istiod',
      repository: 'https://istio-release.storage.googleapis.com/charts',
      namespace: 'istio-system',
      release: 'istiod',
      version: '1.25.0', 
      values: {
        global: {
          hub: `${privateEcrRepository}/istio`,
          tag: '1.25.0',
        },
        pilot: {
          nodeSelector: {
            'node-type': 'memory-optimized', 
          },
        },
      },
      wait: true,
    });
    istiod.node.addDependency(istioBase);

    const gateway = cluster.addHelmChart('IstioGatewayChart', { 
      chart: 'gateway',
      repository: 'https://istio-release.storage.googleapis.com/charts',
      namespace: 'istio-system',
      release: 'istio-ingressgateway',
      version: '1.25.0', 
      values: {
        global: {
          hub: `${privateEcrRepository}/istio`,
          tag: '1.25.0',
        },
        service: {
          type: 'ClusterIP', 
        },
        nodeSelector: {
          'node-type': 'memory-optimized', 
        },
      },
      wait: true,
    });
    gateway.node.addDependency(istiod);
    const lbSubnets = props.vpc.selectSubnets({

      subnetGroupName: 'istio-lb-transit-zone', 
    });

    const trafficControlChart = cluster.addHelmChart('TrafficControlChart', {
      chart: 'hyperswitch-istio',
      repository: 'https://juspay.github.io/hyperswitch-helm/',
      version: '0.1.1',
      release: 'hs-istio', 
      namespace: 'istio-system', 
      values: {
        image: {
          version: 'v1o114o0',
        },
        ingress: {
          enabled: true,
          className: 'alb',
          annotations: {
            'alb.ingress.kubernetes.io/backend-protocol': 'HTTP',
            'alb.ingress.kubernetes.io/backend-protocol-version': 'HTTP1',
            'alb.ingress.kubernetes.io/group.name': 'hyperswitch-istio-app-alb-ingress-group', 
            'alb.ingress.kubernetes.io/healthcheck-interval-seconds': '5',
            'alb.ingress.kubernetes.io/healthcheck-path': '/healthz/ready', 
            'alb.ingress.kubernetes.io/healthcheck-port': '15021',         
            'alb.ingress.kubernetes.io/healthcheck-protocol': 'HTTP',
            'alb.ingress.kubernetes.io/healthcheck-timeout-seconds': '2',
            'alb.ingress.kubernetes.io/healthy-threshold-count': '5',
            'alb.ingress.kubernetes.io/ip-address-type': 'ipv4',
            'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP": 80}]', 
            'alb.ingress.kubernetes.io/load-balancer-attributes': 'routing.http.drop_invalid_header_fields.enabled=true,routing.http.xff_client_port.enabled=true,routing.http.preserve_host_header.enabled=true',
            'alb.ingress.kubernetes.io/scheme': 'internal',
            'alb.ingress.kubernetes.io/security-groups': istioInternalLbSg.securityGroupId, 
            'alb.ingress.kubernetes.io/subnets': lbSubnets.subnetIds.join(','),
            'alb.ingress.kubernetes.io/target-type': 'ip',
            'alb.ingress.kubernetes.io/unhealthy-threshold-count': '3',
          },
          hosts: { 
             paths: [
              {
                path: "/",
                pathType: "Prefix",
                port: 80,
                name: "istio-ingressgateway", 
              },
              {
                path: "/healthz/ready",
                pathType: "Prefix",
                port: 15021,
                name: "istio-ingressgateway", 
              }
            ]
          },
        },
      },
      wait: true,
    });
    this.trafficControlChart = trafficControlChart; 
    this.trafficControlChart.node.addDependency(gateway); 

    // Create a Lambda function to find the Istio ALB DNS name
    const albLookupFunction = new lambda.Function(this, 'GetIstioAlbDnsFunction', {
      runtime: lambda.Runtime.PYTHON_3_9,
      handler: 'get_istio_alb_dns.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, 'lambda')),
      timeout: cdk.Duration.minutes(2),
      description: 'Lambda function to find the DNS name of the Istio ALB',
    });
    
    // Grant permissions to list and describe load balancers
    albLookupFunction.addToRolePolicy(new iam.PolicyStatement({
      actions: [
        'elasticloadbalancing:DescribeLoadBalancers',
        'elasticloadbalancing:DescribeTags'
      ],
      resources: ['*'],
    }));

    // Create custom resource to invoke the Lambda function
    const albLookup = new cr.AwsCustomResource(this, 'IstioAlbDnsLookup', {
      onCreate: {
        service: 'Lambda',
        action: 'invoke',
        parameters: {
          FunctionName: albLookupFunction.functionName,
          Payload: JSON.stringify({
            RequestType: 'Create',
          }),
        },
        physicalResourceId: cr.PhysicalResourceId.of('IstioAlbDnsName'),
      },
      onUpdate: {
        service: 'Lambda',
        action: 'invoke',
        parameters: {
          FunctionName: albLookupFunction.functionName,
          Payload: JSON.stringify({
            RequestType: 'Update',
          }),
        },
        physicalResourceId: cr.PhysicalResourceId.of('IstioAlbDnsName-' + new Date().getTime().toString()),
      },
      policy: cr.AwsCustomResourcePolicy.fromStatements([
        new iam.PolicyStatement({
          actions: ['lambda:InvokeFunction'],
          resources: [albLookupFunction.functionArn],
        }),
      ]),
    });

    albLookup.node.addDependency(trafficControlChart);


    const payloadString = albLookup.getResponseField('Payload'); 
    this.istioInternalAlbDnsName = cdk.Fn.select(
      0,
      cdk.Fn.split(
        '"',
        cdk.Fn.select(1, cdk.Fn.split('"DnsName": "', payloadString))
      )
    );

  }
}
