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
        const ns = cluster.addManifest("logging-ns", {
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

        const fluentdChart = cluster.addHelmChart("fluentd", {
            chart: "fluentd",
            repository: "https://fluent.github.io/helm-charts",
            namespace: "logging",
            wait: false,
            values: {
                kind: "DaemonSet",
                serviceAccount: {
                    create: false,
                    name: sa.serviceAccountName
                },
                fullnameOverride: "fluentd-s3",
                variant: "s3",
                labels: {
                    app: "fluentd-s3"
                },
                resources: {
                    limits: {
                        cpu: "1",
                        memory: "1200Mi"
                    },
                    requests: {
                        cpu: "200m",
                        memory: "150Mi"
                    }
                },
                rbac: {
                    create: false
                 },
                livenessProbe: null,
                readinessProbe: null,
                service: {
                    enabled: false,
                    type: "ClusterIP",
                 },
                image: {
                    repository: "fluent/fluentd-kubernetes-daemonset",
                    pullPolicy: "IfNotPresent",
                    tag: "v1.16-debian-s3-1"
                },
                env: [
                    {
                        name: "S3_BUCKET",
                        value: this.bucket.bucketName,
                    },
                    {
                        name: "S3_REGION",
                        value: process.env.CDK_DEFAULT_REGION,
                    }

                ],
                terminationGracePeriodSeconds: 30,
                dnsPolicy: "ClusterFirst",
                restartPolicy: "Always",
                schedulerName: "default-scheduler",
                securityContext: {},
                fileConfigs:{
                    "01_sources.conf":` <source>
                    @type tail
                    @id in_tail_hyperswitch-server-router_logs
              
                    path /var/log/containers/hyperswitch-*.log
                    pos_file /var/log/fluentd-hyperswitch-server-router-containers.log.pos
                    tag "hyperswitch.*"
                    read_from_head true
                    <parse>
                      @type regexp
                      expression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
                    </parse>
                  </source>`,
                  "02_filters.conf":"",
                  "03_dispatch.conf":"",
                  "04_outputs.conf": `<match hyperswitch.**>
                  <format>
                    @type json
                  </format>
                  @type copy
                  <store>
                    @type stdout
                  </store>
                  <store>
                    @type s3
                    s3_bucket "#{ENV['S3_BUCKET']}"
                    s3_region "#{ENV['S3_REGION']}"
                    path "hyperswitch-logs/%Y/%m/%d/$\{tag\}/"
                    <buffer tag,time>
                      @type file
                      path /var/log/fluent/s3
                      timekey 3600 # 1 hour partition
                      timekey_wait 10m
                      timekey_zone +0530
                      chunk_limit_size 256m
                      flush_at_shutdown
                    </buffer>
                  </store>
                </match>`
                    
                },
            }

        });

        new cdk.CfnOutput(scope, 'LogsS3Bucket', { value: this.bucket.bucketName });
    }
}
