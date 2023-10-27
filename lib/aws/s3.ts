import * as iam from "aws-cdk-lib/aws-iam";
import * as s3 from "aws-cdk-lib/aws-s3";
import { Construct } from "constructs";

export class S3Construct {
  constructor(
    scope: Construct,
    cloudfront_id_1: string, // id used in AWS Principal
    cloudfront_id_2: string, // id used in Service Principal
    cloudfront_account_number: string
  ) {
    const access_logs_bucket = new s3.Bucket(scope, "AccessLogsBucket");
    const s3_bucket = new s3.Bucket(scope, "hyperswitch-s3-bucket", {
      enforceSSL: true,
      minimumTLSVersion: 1.2,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      serverAccessLogsBucket: access_logs_bucket,
      serverAccessLogsPrefix: "logs",
    });

    const bucket_policy = new s3.BucketPolicy(scope, "s3-bucket-policy", {
      bucket: s3_bucket,
    });

    bucket_policy.document.addStatements(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        principals: [
          new iam.ArnPrincipal(
            "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity " +
              cloudfront_id_1
          ),
        ],
        actions: ["s3:GetObject"],
        resources: [`${s3_bucket.bucketArn}/*`],
      }),
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        principals: [new iam.ServicePrincipal("cloudfront.amazonaws.com")],
        actions: ["s3:GetObject"],
        resources: [`${s3_bucket.bucketArn}/*`],
        conditions: {
          "ForAllValues:StringEquals": {
            "aws:sourceArn":
              "arn:aws:cloudfront::" +
              cloudfront_account_number +
              ":distribution/" +
              cloudfront_id_2,
          },
        },
      })
    );

    s3_bucket.grantRead(new iam.AccountRootPrincipal());
  }
}
