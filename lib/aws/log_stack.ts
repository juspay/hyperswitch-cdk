import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as cdk from "aws-cdk-lib";
import { Construct } from 'constructs';
import * as s3 from "aws-cdk-lib/aws-s3";
import * as iam from "aws-cdk-lib/aws-iam";
import * as eks from "aws-cdk-lib/aws-eks";
import * as opensearch from 'aws-cdk-lib/aws-opensearchservice';
import { Domain, EngineVersion, IpAddressType } from 'aws-cdk-lib/aws-opensearchservice';


export class LogsStack {
    bucket: s3.Bucket;
    domain: Domain;
    constructor(scope: Construct, cluster: eks.Cluster, serviceAccountName?: string) {
        this.bucket = new s3.Bucket(scope, "LogsBucket", {
            removalPolicy: cdk.RemovalPolicy.DESTROY,
            bucketName: `logs-bucket-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}`,
        });
        cluster.node.addDependency(this.bucket);
        const loggingNS = cluster.addManifest("logging-ns", {
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
        sa.node.addDependency(loggingNS);
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
                fileConfigs: {
                    "01_sources.conf": ` <source>
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
                    "02_filters.conf": "",
                    "03_dispatch.conf": "",
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

        fluentdChart.node.addDependency(sa);

        this.domain = new opensearch.Domain(scope, 'OpenSearch', {
            version: opensearch.EngineVersion.OPENSEARCH_2_11,
            enableVersionUpgrade: false,
            ebs: {
              volumeSize: 50,
              volumeType: ec2.EbsDeviceVolumeType.GP3,
              throughput: 125,
              iops: 3000,
            },
            fineGrainedAccessControl: {
              masterUserName: "admin",
              masterUserPassword: cdk.SecretValue.unsafePlainText("Pluentd@123"),
            },
            nodeToNodeEncryption: true,
            encryptionAtRest: {
              enabled: true,
            },
            removalPolicy: cdk.RemovalPolicy.DESTROY,
            enforceHttps: true,
            zoneAwareness:{
              enabled: true,
              availabilityZoneCount: 2
            },
            capacity: {
              dataNodes: 2,
              dataNodeInstanceType: "r6g.large.search",
              multiAzWithStandbyEnabled: false
            }
        });
        // this.domain.grantReadWrite(new iam.AnyPrincipal());
        const policy = new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          principals: [new iam.AnyPrincipal()],
          actions: ["es:*"],
          resources: [`${this.domain.domainArn}/*`],
        });
        this.domain.addAccessPolicies(policy);

        const kAnalyticsNS = cluster.addManifest("kube-analytics-ns", {
            "apiVersion": "v1",
            "kind": "Namespace",
            "metadata": {
                "name": "kube-analytics"
            }
        });

        kAnalyticsNS.node.addDependency(this.domain);

        const openSearchFluentdChart = cluster.addHelmChart("fluentd-opensearch", {
            chart: "fluentd",
            repository: "https://fluent.github.io/helm-charts",
            namespace: "kube-analytics",
            wait: false,
            values: {
                kind: "DaemonSet",
                serviceAccount: {
                    create: false,
                    name: null
                },
                fullnameOverride: "fluentd-opensearch",
                variant: "opensearch",
                labels: {
                    app: "fluentd-opensearch"
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
                    create: true
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
                    tag: "v1.16-debian-opensearch-2"
                },
                env: [
                    {
                        name: "FLUENT_OPENSEARCH_HOST",
                        value: this.domain.domainEndpoint,
                    },
                    {
                        name: "FLUENT_OPENSEARCH_PORT",
                        value: "443",
                    },
                    {
                        name: "FLUENT_OPENSEARCH_SSL_VERIFY",
                        value: "true",
                    },
                    {
                        name: "FLUENT_OPENSEARCH_USER_NAME",
                        value: `${process.env.MASTER_USER_NAME}`,
                    },
                    {
                        name: "FLUENT_OPENSEARCH_PASSWORD",
                        value: `${process.env.MASTER_PASSWORD}`,
                    },
                    {
                        name: "FLUENT_OPENSEARCH_SCHEME",
                        value: "https",
                    }

                ],
                terminationGracePeriodSeconds: 30,
                dnsPolicy: "ClusterFirst",
                restartPolicy: "Always",
                schedulerName: "default-scheduler",
                securityContext: {},
                fileConfigs: {
                    "01_sources.conf": `
                        <source>
                            @type tail
                            @id in_tail_hyperswitch-server-router_logs

                            path /var/log/containers/hyperswitch-server*.log
                            pos_file /var/log/fluentd-hyperswitch-server-router-containers.log.pos
                            tag "hyperswitch.router"
                            read_from_head true
                            <parse>
                                @type regexp
                                expression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
                            </parse>
                        </source>

                        <source>
                            @type tail
                            @id in_tail_hyperswitch-consumer_logs

                            path /var/log/containers/hyperswitch-consumer*hyperswitch-*.log
                            pos_file /var/log/fluentd-hyperswitch-consumer-containers.log.pos
                            tag "hyperswitch.consumer"
                            read_from_head true
                            <parse>
                                @type regexp
                                expression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
                            </parse>
                        </source>

                        # Hyperswitch Drainer Source
                        <source>
                            @type tail
                            @id in_tail_hyperswitch-drainer_logs

                            path /var/log/containers/hyperswitch-drainer*hyperswitch-*.log
                            pos_file /var/log/fluentd-hyperswitch-drainer-containers.log.pos
                            tag "hyperswitch.drainer"
                            read_from_head true
                            <parse>
                                @type regexp
                                expression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
                            </parse>
                        </source>

                        # HyperSwitch Producer Source
                        <source>
                            @type tail
                            @id in_tail_hyperswitch-producer_logs

                            path /var/log/containers/hyperswitch-producer*hyperswitch-*.log
                            pos_file /var/log/fluentd-hyperswitch-producer-containers.log.pos
                            tag "hyperswitch.producer"
                            read_from_head true
                            <parse>
                                @type regexp
                                expression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
                            </parse>
                        </source>`,
                    
                    "02_filters.conf": `
                        # Parse JSON Logs
                        <filter hyperswitch.**>
                            @type parser

                            key_name log
                            reserve_time true
                            <parse>
                                @type multi_format
                                <pattern>
                                    format json
                                    hash_value_field json_log
                                    format_name 'json'
                                </pattern>
                                <pattern>
                                    format regexp
                                    expression /^(?<message>.*)$/
                                    format_name 'raw_message'
                                </pattern>
                            </parse>
                        </filter>
                        # Add kubernetes metadata
                        <filter hyperswitch.**>
                            @type kubernetes_metadata
                        </filter>`,
                    
                    "03_dispatch.conf": "",

                    "04_outputs.conf": `
                        <match hyperswitch.**>
                            <format>
                                @type json
                            </format>
                            @type copy
                            <store>
                                @type opensearch
                                @id hyperswitch-out_es
                                id_key _hash
                                remove_keys _hash
                                @log_level debug
                                prefer_oj_serializer true
                                reload_on_failure true
                                reload_connections false
                                user "#{ENV['FLUENT_OPENSEARCH_USER_NAME']}"
                                password "#{ENV['FLUENT_OPENSEARCH_PASSWORD']}"
                                request_timeout 120s
                                bulk_message_request_threshold 10MB
                                host "#{ENV['FLUENT_OPENSEARCH_HOST']}"
                                port "#{ENV['FLUENT_OPENSEARCH_PORT']}"
                                scheme "#{ENV['FLUENT_OPENSEARCH_SCHEME'] || 'http'}"
                                ssl_verify "#{ENV['FLUENT_OPENSEARCH_SSL_VERIFY'] || 'true'}"
                                logstash_prefix logstash-$\{tag\}
                                include_timestamp true
                                logstash_format true
                                type_name fluentd
                                <buffer>
                                    @type file
                                    path /var/log/opensearch-buffers/hyperswitch-buffer
                                    flush_thread_count 6
                                    flush_interval 1s
                                    chunk_limit_size 5M
                                    queue_limit_length 4
                                    flush_mode interval
                                    retry_max_interval 30
                                    retry_type exponential_backoff
                                    overflow_action drop_oldest_chunk
                                </buffer>
                            </store>
                        </match>`
                },
                ingress:{
                    enabled: false,
                }
            }

        });
        openSearchFluentdChart.node.addDependency(kAnalyticsNS);


        new cdk.CfnOutput(scope, 'LogsS3Bucket', { value: this.bucket.bucketName });
        new cdk.CfnOutput(scope, 'OpenSearch Endpoint', { value: this.domain.domainEndpoint });
    }
}
