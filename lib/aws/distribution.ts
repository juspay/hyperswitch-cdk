import { Construct } from 'constructs';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as cdk from 'aws-cdk-lib';

interface DistributionProps {
  controlCenterHost: string;
  appHost: string;
}

export class DistributionConstruct extends Construct {
  public readonly routerDistribution: cloudfront.Distribution;
  constructor(scope: Construct, id: string, props: DistributionProps) {
    super(scope, id);

    const controlCenterDistribution = new cloudfront.Distribution(this, 'ControlCenterDistribution', {
      defaultBehavior: {
        origin: new origins.HttpOrigin(props.controlCenterHost, {
          protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
        }),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.ALLOW_ALL,
        originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
        cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
      },
    });

    new cdk.CfnOutput(this, 'ControlCenterDistributionDomain', {
      value: controlCenterDistribution.distributionDomainName,
    });

    this.routerDistribution = new cloudfront.Distribution(this, 'RouterDistribution', {
      defaultBehavior: {
        origin: new origins.HttpOrigin(props.appHost, {
          protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
        }),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.ALLOW_ALL,
        originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
        cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
      },
    });

    new cdk.CfnOutput(this, 'RouterDistributionDomain', {
      value: this.routerDistribution.distributionDomainName,
    });
  }
}