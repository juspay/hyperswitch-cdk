import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
import { Config } from "./config";
import { DataBaseConstruct } from "./rds";
import * as cr from "aws-cdk-lib/custom-resources";
import { PolicyStatement } from "aws-cdk-lib/aws-iam";
import * as cdk from "aws-cdk-lib/core";
import { EksStack } from "./eks";

export class HyperswitchSDKStack {
  constructor(
    scope: Construct,
    config: Config,
    vpc: ec2.Vpc,
    rds: DataBaseConstruct,
    eks: EksStack
  ) {
    // Create a new S3 bucket
    const bucket = rds.bucket;
    let sdkVersion = '0.5.0';

    fetch('https://raw.githubusercontent.com/juspay/hyperswitch-web/main/package.json')
      .then(response => response.json())
      .then(data => {
        sdkVersion = data.version;
        // Output a field from the JSON
        new cdk.CfnOutput(scope, 'HyperLoaderUrl', {
          value: "http://"+rds.bucket.bucketDomainName+"/"+data.version+"/v0",
        });
      })
      .catch(error => console.error(error));

    // Create a new CodeBuild project
    const project = new codebuild.Project(scope, "HyperswitchSDK", {
      projectName: "HyperswitchSDK",
      buildSpec: codebuild.BuildSpec.fromObject({
        version: "0.2",
        phases: {
          install: {
            commands: [
              "export envBackendUrl=\"http://$(aws elbv2 describe-load-balancers --name 'hyperswitch' --query 'LoadBalancers[].DNSName' --output text)\"",
              "git clone https://github.com/juspay/hyperswitch-web",
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
              "export sdkVersion=$(node -e \"console.log(require('./package.json').version);\")",
              "aws s3 cp --recursive dist/integ/ s3://$sdkBucket/$sdkVersion/v0",
            ],
          },
        },
      }),
      environmentVariables: {
        sdkBucket: {
          value: rds.bucket.bucketName,
          type: codebuild.BuildEnvironmentVariableType.PLAINTEXT,
        },
        envSdkUrl: {
          value: "http://" + rds.bucket.bucketDomainName,
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

    // Allow the CodeBuild project to access the S3 bucket
    bucket.grantReadWrite(project);

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
