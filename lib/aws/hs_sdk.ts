import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
import { Config } from "./config";
import { DataBaseConstruct } from "./rds";
import * as cr from 'aws-cdk-lib/custom-resources';

export class HyperswitchSDKStack {
  constructor(
    scope: Construct,
    config: Config,
    vpc: ec2.Vpc,
    rds: DataBaseConstruct
  ) {
    // Create a new S3 bucket
    const bucket = rds.bucket;

    // Create a new CodeBuild project
    const project = new codebuild.Project(scope, "HyperswitchSDK", {
      projectName: "HyperswitchSDK",
      buildSpec: codebuild.BuildSpec.fromObject({
        version: "0.2",
        phases: {
          install: {
            commands: [
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
            commands: "npm run build:dev",
          },
          post_build: {
            commands: [
              "aws s3 cp dist/sandbox/HyperLoader.js s3://hyperswitch-schema-225681119357-us-east-2/",
            ],
          },
        },
      }),
      environment: {
        buildImage: codebuild.LinuxBuildImage.AMAZON_LINUX_2_5,
      },
    });

    // Allow the CodeBuild project to access the S3 bucket
    bucket.grantReadWrite(project);
    
    // Create a custom resource that starts a build when the project is created
    new cr.AwsCustomResource(scope, 'StartBuild', {
      onCreate: {
        service: 'CodeBuild',
        action: 'startBuild',
        parameters: {
          projectName: project.projectName,
        },
        physicalResourceId: cr.PhysicalResourceId.of('StartBuild'),
      },
      policy: cr.AwsCustomResourcePolicy.fromSdkCalls({resources: cr.AwsCustomResourcePolicy.ANY_RESOURCE}),
    });
  }
}
