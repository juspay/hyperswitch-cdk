import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as cdk from "aws-cdk-lib";
import { Construct } from 'constructs';
import * as s3 from "aws-cdk-lib/aws-s3";
import * as iam from "aws-cdk-lib/aws-iam";
import * as eks from "aws-cdk-lib/aws-eks";


export class LogsBucket {
    bucket: s3.Bucket;
    constructor(scope: Construct, cluster: eks.Cluster, serviceAccountName?: string) {
        this.bucket = new s3.Bucket(scope, "LogsBucket", {
            removalPolicy: cdk.RemovalPolicy.DESTROY,
            bucketName: `logs-bucket-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}`,
        });
        cluster.node.addDependency(this.bucket);
        const ns = cluster.addManifest("logging-ns",  {
            "apiVersion": "v1",
            "kind": "Namespace",
            "metadata": {
                "name": "logging"
            }
        })
        const sa = cluster.addServiceAccount("app-logs-s3-service-account", {
            name: serviceAccountName,
            namespace: "logging"
        });
        sa.node.addDependency(ns);
        this.bucket.grantReadWrite(sa);
        new cdk.CfnOutput(scope, 'LogsS3Bucket', { value: this.bucket.bucketName });
    }
}
