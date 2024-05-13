import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
import { Config } from "./config";
import * as cr from "aws-cdk-lib/custom-resources";
import { PolicyStatement } from "aws-cdk-lib/aws-iam";
import * as cdk from "aws-cdk-lib/core";
import * as s3 from 'aws-cdk-lib/aws-s3';
import { EksStack } from "./eks";
import * as iam from "aws-cdk-lib/aws-iam";
import { readFileSync } from "fs";
import { Code, Function, Runtime } from "aws-cdk-lib/aws-lambda";

export class HyperswitchSDKStack {
  constructor(
    scope: Construct,
    eks: EksStack,
  ) {

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
          ],
          resources: ["*"],
        }),
      ]
    });

    sdkBuildRole.attachInlinePolicy(
      new iam.Policy(scope, "SDKBucketAccessPolicy", {
        document: sdkBuildPolicy,
      }),
    );

    let sdkVersion = "0.27.2";

    // Create a new CodeBuild project
    const project = new codebuild.Project(scope, "HyperswitchSDK", {
      projectName: "HyperswitchSDK",
      role: sdkBuildRole,
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
          value: eks.sdkBucket.bucketName,
          type: codebuild.BuildEnvironmentVariableType.PLAINTEXT,
        },
        envSdkUrl: {
          value: "http://" + eks.sdkDistribution.distributionDomainName,
          type: codebuild.BuildEnvironmentVariableType.PLAINTEXT,
        },
      },
      environment: {
        buildImage: codebuild.LinuxBuildImage.AMAZON_LINUX_2_5,
      },
    });
    // Allow the CodeBuild project to access the S3 bucket
    eks.sdkBucket.grantReadWrite(project);

    project.node.addDependency(eks.lokiChart);

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
      ]
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
        })
      ]
    })

    triggerCodeBuildRole.attachInlinePolicy(
      new iam.Policy(scope, "SdkAssetsUploadLambdaPolicy", {
        document: triggerCodeBuildPolicy,
      }),
    );

    triggerCodeBuildRole.attachInlinePolicy(
      new iam.Policy(scope, "SdkAssetsUploadLambdaLogsPolicy", {
        document: logsPolicy,
      }),
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
