import { Construct } from "constructs";
import { aws_wafv2 as wafv2 } from "aws-cdk-lib";
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cdk from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam";

export class WAF extends Construct {
  readonly waf_arn: string;
  readonly waf_acl_id: string;
  constructor(scope: Construct, id: string) {
    super(scope, id);

    const webAcl = new wafv2.CfnWebACL(this, "WebACL", {
      scope: "REGIONAL",
      defaultAction: {
        allow: {},
      },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: "WebACL",
        sampledRequestsEnabled: true,
      },
      rules: [
        {
          name: "allow_merchant_admin",
          priority: 0,
          action: {
            allow: {}
          },
          statement: {
            byteMatchStatement: {
              fieldToMatch: {
                uriPath: {}
              },
              positionalConstraint: "ENDS_WITH",
              searchString: "merchant_admin",
              textTransformations: [
                {
                  type: "NONE",
                  priority: 0
                }
              ]
            }
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "allow_merchant_admin",
            sampledRequestsEnabled: true,
          }
        },
        {
          name: "health_status",
          priority: 1,
          action: {
            allow: {}
          },
          statement: {
            byteMatchStatement: {
              fieldToMatch: {
                singleHeader: {
                  "Name": "x-hyperswitch-betterstack"
                }
              },
              positionalConstraint: "EXACTLY",
              searchString: "Betterstack-ironman",
              textTransformations: [
                {
                  type: "NONE",
                  priority: 0
                }
              ]
            }
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "health_status",
            sampledRequestsEnabled: true,
          }
        },
        {
          name: "allow_pingdom",
          priority: 2,
          action: {
            allow: {}
          },
          statement: {
            byteMatchStatement: {
              fieldToMatch: {
                singleHeader: {
                  "Name": "user-agent"
                }
              },
              positionalConstraint: "EXACTLY",
              searchString: "Pingdom.com_bot_version_1.4_(http://www.pingdom.com/)",
              textTransformations: [
                {
                  type: "NONE",
                  priority: 0
                }
              ]
            }
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "allow_pingdom",
            sampledRequestsEnabled: true,
          }
        },
        {
          name: "AWS-AWSManagedRulesKnownBadInputsRuleSet",
          priority: 3,
          statement: {
            managedRuleGroupStatement: {
              name: "AWSManagedRulesKnownBadInputsRuleSet",
              vendorName: "AWS",
              ruleActionOverrides: [
                {
                  name: "JavaDeserializationRCE_BODY",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "JavaDeserializationRCE_URIPATH",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "JavaDeserializationRCE_QUERYSTRING",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "JavaDeserializationRCE_HEADER",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "Host_localhost_HEADER",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "PROPFIND_METHOD",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "ExploitablePaths_URIPATH",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "Log4JRCE_QUERYSTRING",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "Log4JRCE_BODY",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "Log4JRCE_URIPATH",
                  actionToUse: {
                    block: {}
                  }
                },
                {
                  name: "Log4JRCE_HEADER",
                  actionToUse: {
                    block: {}
                  }
                }
              ]
            },
          },
          overrideAction: {
            none: {},
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "AWS-AWSManagedRulesKnownBadInputsRuleSet",
            sampledRequestsEnabled: true,
          }
        },
        {
          name: "AWS-AWSManagedRulesCommonRuleSet",
          priority: 4,
          statement: {
            managedRuleGroupStatement: {
              name: "AWSManagedRulesCommonRuleSet",
              vendorName: "AWS",
              ruleActionOverrides: [
                {
                  name: "NoUserAgent_HEADER",
                  actionToUse: {
                    allow: {},
                  },
                },
                {
                  name: "UserAgent_BadBots_HEADER",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "SizeRestrictions_QUERYSTRING",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "SizeRestrictions_Cookie_HEADER",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "SizeRestrictions_BODY",
                  actionToUse: {
                    allow: {},
                  },
                },
                {
                  name: "SizeRestrictions_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "EC2MetaDataSSRF_BODY",
                  actionToUse: {
                    allow: {},
                  },
                },
                {
                  name: "EC2MetaDataSSRF_COOKIE",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "EC2MetaDataSSRF_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "GenericLFI_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "GenericLFI_QUERYARGUMENTS",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "EC2MetaDataSSRF_QUERYARGUMENTS",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "GenericLFI_BODY",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "RestrictedExtensions_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "RestrictedExtensions_QUERYARGUMENTS",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "GenericRFI_QUERYARGUMENTS",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "GenericRFI_BODY",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "GenericRFI_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "CrossSiteScripting_COOKIE",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "CrossSiteScripting_QUERYARGUMENTS",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "CrossSiteScripting_BODY",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "CrossSiteScripting_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                },
              ],
            },
          },
          overrideAction: {
            none: {},
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "AWS-AWSManagedRulesCommonRuleSet",
            sampledRequestsEnabled: true,
          },
        },
        {
          name: "AWS-AWSManagedRulesSQLiRuleSet",
          priority: 5,
          statement: {
            managedRuleGroupStatement: {
              name: "AWSManagedRulesSQLiRuleSet",
              vendorName: "AWS",
              ruleActionOverrides: [
                {
                  name: "SQLi_BODY",
                  actionToUse: {
                    allow: {},
                  },
                },
                {
                  name: "SQLiExtendedPatterns_QUERYARGUMENTS",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "SQLi_QUERYARGUMENTS",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "SQLi_COOKIE",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "SQLi_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                },
              ]
            },
          },
          overrideAction: {
            none: {},
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "AWS-AWSManagedRulesSQLiRuleSet",
            sampledRequestsEnabled: true,
          }
        },
        {
          name: "AWS-AWSManagedRulesAdminProtectionRuleSet",
          priority: 6,
          statement: {
            managedRuleGroupStatement: {
              name: "AWSManagedRulesAdminProtectionRuleSet",
              vendorName: "AWS",
              ruleActionOverrides: [
                {
                  name: "AdminProtection_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                }
              ]
            },
          },
          overrideAction: {
            none: {},
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "AWS-AWSManagedRulesAdminProtectionRuleSet",
            sampledRequestsEnabled: true,
          }
        },
        {
          name: "AWS-AWSManagedRulesAmazonIpReputationList",
          priority: 7,
          statement: {
            managedRuleGroupStatement: {
              name: "AWSManagedRulesAmazonIpReputationList",
              vendorName: "AWS",
              ruleActionOverrides: [
                {
                  name: "AWSManagedIPDDoSList",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "AWSManagedIPReputationList",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "AWSManagedReconnaissanceList",
                  actionToUse: {
                    block: {},
                  },
                },
              ]
            },
          },
          overrideAction: {
            none: {},
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "AWS-AWSManagedRulesAmazonIpReputationList",
            sampledRequestsEnabled: true,
          }
        },
        {
          name: "AWS-AWSManagedRulesLinuxRuleSet",
          priority: 8,
          statement: {
            managedRuleGroupStatement: {
              name: "AWSManagedRulesLinuxRuleSet",
              vendorName: "AWS",
              ruleActionOverrides: [
                {
                  name: "LFI_URIPATH",
                  actionToUse: {
                    block: {},
                  },
                },
                {
                  name: "LFI_QUERYSTRING",
                  actionToUse: {
                    block: {},
                  },
                }
              ]
            },
          },
          overrideAction: {
            none: {},
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "AWS-AWSManagedRulesLinuxRuleSet",
            sampledRequestsEnabled: true,
          }
        },
      ],
    });


    let server_access_logs_bucket =  new s3.Bucket(scope, "serverLogsHyperswitch", {
      bucketName: `serveraccesslogs-hyperswitch-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}`,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: true,
      }),
      publicReadAccess: false,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    const serverAccessLogsPolicy = new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      principals: [new iam.ServicePrincipal('logging.s3.amazonaws.com')],
      actions: ['s3:PutObject'],
      resources: [`${server_access_logs_bucket.bucketArn}/*`],
      conditions: {
        StringEquals: {
          'aws:SourceAccount': process.env.CDK_DEFAULT_ACCOUNT,
        },
      },
    });

    const allowSSLReqOnlyServerAccessPolicy = new iam.PolicyStatement({
      effect: iam.Effect.DENY,
      principals: [new iam.AnyPrincipal()],
      actions: ['s3:*'],
      resources: [server_access_logs_bucket.bucketArn, `${server_access_logs_bucket.bucketArn}/*`],
      conditions: {
        Bool: {
          'aws:SecureTransport': 'false',
        },
      },
    });

    server_access_logs_bucket.addToResourcePolicy(allowSSLReqOnlyServerAccessPolicy);

    let waf_logs_bucket = new s3.Bucket(scope, "awsWAFLogsHyperswitch", {
      bucketName: `aws-waf-logs-hyperswitch-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}`,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: true,
      }),
      publicReadAccess: false,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      serverAccessLogsBucket:server_access_logs_bucket,
      targetObjectKeyFormat: s3.TargetObjectKeyFormat.simplePrefix(),
    });

    const weblogging = new wafv2.CfnLoggingConfiguration(this, "WebACLLogging", {
      resourceArn: webAcl.attrArn,
      logDestinationConfigs: [waf_logs_bucket.bucketArn]
    });

    const wafLogsPolicy = new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      principals: [new iam.ServicePrincipal('delivery.logs.amazonaws.com')],
      actions: ['s3:PutObject'],
      resources: [`${waf_logs_bucket.bucketArn}/AWSLogs/*`],
      conditions: {
        StringEquals: {
          's3:x-amz-acl': 'bucket-owner-full-control',
          'aws:SourceAccount': process.env.CDK_DEFAULT_ACCOUNT,
        },
        ArnLike: {
          'aws:SourceArn': `arn:aws:logs:${process.env.CDK_DEFAULT_REGION}:${process.env.CDK_DEFAULT_ACCOUNT}:*`,
        },
      },
    });
    
    const wafLogsAclPolicy = new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      principals: [new iam.ServicePrincipal('delivery.logs.amazonaws.com')],
      actions: ['s3:GetBucketAcl'],
      resources: [waf_logs_bucket.bucketArn],
      conditions: {
        StringEquals: {
          'aws:SourceAccount': process.env.CDK_DEFAULT_ACCOUNT,
        },
        ArnLike: {
          'aws:SourceArn': `arn:aws:logs:${process.env.CDK_DEFAULT_REGION}:${process.env.CDK_DEFAULT_ACCOUNT}:*`,
        },
      },
    });
    
    const denyUnsecuredAccessPolicy = new iam.PolicyStatement({
      effect: iam.Effect.DENY,
      principals: [new iam.AnyPrincipal()],
      actions: ['s3:*'],
      resources: [waf_logs_bucket.bucketArn, `${waf_logs_bucket.bucketArn}/*`],
      conditions: {
        Bool: {
          'aws:SecureTransport': 'false',
        },
      },
    });
    
    waf_logs_bucket.addToResourcePolicy(wafLogsPolicy);
    waf_logs_bucket.addToResourcePolicy(wafLogsAclPolicy);
    waf_logs_bucket.addToResourcePolicy(denyUnsecuredAccessPolicy);

    this.waf_arn = webAcl.attrArn;
    this.waf_acl_id = webAcl.attrId;
  }
}