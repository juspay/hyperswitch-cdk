import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as ssm from "aws-cdk-lib/aws-ssm";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import { SSMConfig } from "./config";

function addEntityToSSM(
  scope: Construct,
  entity: iam.IRole,
  config: SSMConfig,
) {
  entity.addManagedPolicy(
    iam.ManagedPolicy.fromManagedPolicyArn(
      scope,
      "SSM Policy",
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    ),
  );

  const customSSMPolicy = new iam.Policy(scope, "custom-ssm-policy", {
    statements: [
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ],
        resources: ["*"],
      }),
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ["s3:PutObject"],
        resources: [`arn:aws:s3:::s3://${config.log_bucket_name}/*`],
      }),
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ["s3:GetEncryptionConfiguration"],
        resources: ["*"],
      }),
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ["kms:GenerateDataKey"],
        resources: ["*"],
      }),
    ],
  });

  entity.attachInlinePolicy(customSSMPolicy);
}
