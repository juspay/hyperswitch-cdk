import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
import { Config } from "./config";
import * as cr from "aws-cdk-lib/custom-resources";
import { PolicyStatement } from "aws-cdk-lib/aws-iam";
import * as cdk from "aws-cdk-lib";
import * as s3 from 'aws-cdk-lib/aws-s3';
import { EksStack } from "./eks";
import { DistributionConstruct } from "./distribution"
import * as iam from "aws-cdk-lib/aws-iam";
import { readFileSync } from "fs";
import { Code, Function, Runtime } from "aws-cdk-lib/aws-lambda";

export class HyperswitchSDKStack extends Construct {
  constructor(scope: Construct, eks: EksStack, distribution: DistributionConstruct ) {
    super(scope, 'HyperswitchSDKStack');

    const sdkBuildRole = new iam.Role(scope, "sdkBucketRole", {
      assumedBy: new iam.ServicePrincipal("codebuild.amazonaws.com"),
    });

    const sdkBuildPolicy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: [
            "s3:putObject",
            "s3:getObject",
            "s3:ListBucket",
            "elasticloadbalancing:DescribeLoadBalancers",
            "elbv2:DescribeLoadBalancers",
            "cloudfront:ListDistributions"
          ],
          resources: ["*"],
        }),
      ],
    });

    sdkBuildRole.attachInlinePolicy(
      new iam.Policy(scope, "SDKBucketAccessPolicy", {
        document: sdkBuildPolicy,
      })
    );

    let sdkVersion = "0.121.2";

    const project = new codebuild.Project(scope, "HyperswitchSDK", {
      projectName: "HyperswitchSDK",
      role: sdkBuildRole,
      buildSpec: codebuild.BuildSpec.fromObject({
        version: "0.2",
        phases: {
          install: {
            commands: [
              'LB_NAME=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?LoadBalancerName==\'envoy-external-lb\'].LoadBalancerName | [0]" --output text)',
              'if [ "$LB_NAME" = "None" ] || [ -z "$LB_NAME" ]; then LB_NAME="hyperswitch"; fi',
              'HOST=$(aws elbv2 describe-load-balancers --names $LB_NAME --query "LoadBalancers[0].DNSName" --output text)',
              'BACKEND_URL=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[?DomainName==\'${HOST}\']].DomainName" --output text)',
              'export ENV_BACKEND_URL="https://${BACKEND_URL}"',
              "git clone --branch v" + sdkVersion + " https://github.com/juspay/hyperswitch-web",
              "cd hyperswitch-web",
              "curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o n",
              "chmod +x n",
              "./n 18",
              "npm install",
              "npm run re:build",
            ],
          },
          build: {
            commands: "ENV_SDK_URL=$envSdkUrl npm run build:sandbox",
          },
          post_build: {
            commands: [
              "aws s3 cp --recursive dist/sandbox/ s3://$sdkBucket/web/" + sdkVersion + "/",
            ],
          },
        },
      }),
      environmentVariables: {
        sdkBucket: {
          value: eks.sdkBucket.bucketName,
          type: codebuild.BuildEnvironmentVariableType.PLAINTEXT,
        },
        envSdkUrl: {
          value: "https://" + eks.sdkDistribution.distributionDomainName,
          type: codebuild.BuildEnvironmentVariableType.PLAINTEXT,
        },
      },
      environment: {
        buildImage: codebuild.LinuxBuildImage.AMAZON_LINUX_2_5,
      },
    });

    eks.sdkBucket.grantReadWrite(project);

    project.node.addDependency(eks.lokiChart); 
    project.node.addDependency(distribution.routerDistribution);

    const lambdaStartBuildCode = readFileSync('./dependencies/code_builder/start_build.py').toString();

    const triggerCodeBuildRole = new iam.Role(scope, "SdkAssetsUploadLambdaRole", {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
    });

    const triggerCodeBuildPolicy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: [
            "codebuild:StartBuild",
          ],
          resources: [project.projectArn],
        }),
      ],
    });

    const logsPolicy = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          actions: [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ],
          resources: ["*"],
        }),
      ],
    });

    triggerCodeBuildRole.attachInlinePolicy(
      new iam.Policy(scope, "SdkAssetsUploadLambdaPolicy", {
        document: triggerCodeBuildPolicy,
      })
    );

    triggerCodeBuildRole.attachInlinePolicy(
      new iam.Policy(scope, "SdkAssetsUploadLambdaLogsPolicy", {
        document: logsPolicy,
      })
    );

    const triggerCodeBuild = new Function(scope, "SdkAssetsUploadLambda", {
      runtime: Runtime.PYTHON_3_9,
      handler: "index.lambda_handler",
      code: Code.fromInline(lambdaStartBuildCode),
      timeout: cdk.Duration.minutes(15),
      role: triggerCodeBuildRole,
      environment: {
        PROJECT_NAME: project.projectName,
      },
    });

    const codebuildTrigger = new cdk.CustomResource(scope, "SdkAssetsUploadCR", {
      serviceToken: triggerCodeBuild.functionArn,
    });
  }
}