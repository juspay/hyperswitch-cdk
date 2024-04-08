import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
import { Config } from "./config";
import * as cr from "aws-cdk-lib/custom-resources";
import { PolicyStatement } from "aws-cdk-lib/aws-iam";
import * as cdk from "aws-cdk-lib/core";
import * as s3 from 'aws-cdk-lib/aws-s3';
import { EksStack } from "./eks";
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import { S3Origin } from "aws-cdk-lib/aws-cloudfront-origins";

export class HyperswitchSDKStack {
  constructor(
    scope: Construct,
    config: Config,
    vpc: ec2.Vpc,
    eks: EksStack
  ) {
    const sdkCorsRule: s3.CorsRule = {
      allowedOrigins: ["*"],
      allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.HEAD],
      allowedHeaders: ["*"],
      maxAge: 3000,
    }

    const bucket = new s3.Bucket(scope, "HyperswitchSDKBucket", {
      bucketName: "hyperswitch-sdk",
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: true,
      }),
      publicReadAccess: false,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      cors: [sdkCorsRule],
    });
    let sdkVersion = "0.27.2";

    // Create a new CodeBuild project
    const project = new codebuild.Project(scope, "HyperswitchSDK", {
      projectName: "HyperswitchSDK",
      buildSpec: codebuild.BuildSpec.fromObject({
        version: "0.2",
        phases: {
          install: {
            commands: [
              "export envBackendUrl=\"http://$(aws elbv2 describe-load-balancers --name 'hyperswitch' --query 'LoadBalancers[].DNSName' --output text)\"",
              "git clone --branch v"+sdkVersion+" https://github.com/juspay/hyperswitch-web",
              "cd hyperswitch-web",
              "n install 18",
              "npm -v",
              "node --version",
              "npm install",
              "npm run re:build",
            ],
          },
          build: {
            commands: "envSdkUrl=$envSdkUrl envBackendUrl=$envBackendUrl npm run build:integ",
          },
          post_build: {
            commands: [
              "aws s3 cp --recursive dist/integ/ s3://$sdkBucket/"+sdkVersion+"/v0",
            ],
          },
        },
      }),
      environmentVariables: {
        sdkBucket: {
          value: bucket.bucketName,
          type: codebuild.BuildEnvironmentVariableType.PLAINTEXT,
        },
        envSdkUrl: {
          value: "http://" + bucket.bucketDomainName,
          type: codebuild.BuildEnvironmentVariableType.PLAINTEXT,
        },
      },
      environment: {
        buildImage: codebuild.LinuxBuildImage.AMAZON_LINUX_2_5,
      },
    });
    project.node.addDependency(eks.lokiChart);

    project.addToRolePolicy(
      new PolicyStatement({
        actions: ["elasticloadbalancing:DescribeLoadBalancers"],
        resources: ["*"], // Modify this to restrict access to specific resources
      })
    );

    project.addToRolePolicy(
      new PolicyStatement({
        actions: ["logs:CreateLogStream"],
        resources: ["*"],
      })
    );

    // Allow the CodeBuild project to access the S3 bucket
    bucket.grantReadWrite(project);

    const oai = new cloudfront.OriginAccessIdentity(scope, 'SdkOAI');
    bucket.grantRead(oai);

    let sdkDistribution = new cloudfront.CloudFrontWebDistribution(scope, 'sdkDistribution', {
      originConfigs: [
        {
        s3OriginSource: {
          s3BucketSource: bucket,
          originAccessIdentity: oai,
        },
        behaviors: [{isDefaultBehavior: true}, {pathPattern: '/*', allowedMethods: cloudfront.CloudFrontAllowedMethods.GET_HEAD}]
      }
      ]
    });

    new cdk.CfnOutput(scope, 'SdkDistribution', {
      value: sdkDistribution.distributionDomainName,
    });

    // Create a custom resource that starts a build when the project is created
    new cr.AwsCustomResource(scope, "StartBuild", {
      onCreate: {
        service: "CodeBuild",
        action: "startBuild",
        parameters: {
          projectName: project.projectName,
        },
        physicalResourceId: cr.PhysicalResourceId.of("StartBuild"),
      },
      policy: cr.AwsCustomResourcePolicy.fromSdkCalls({
        resources: cr.AwsCustomResourcePolicy.ANY_RESOURCE,
      }),
    });
  }
}
