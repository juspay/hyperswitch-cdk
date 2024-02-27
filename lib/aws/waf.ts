import { Construct } from "constructs";
import { aws_wafv2 as wafv2 } from "aws-cdk-lib";

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
          name: "CRSRule",
          priority: 0,
          statement: {
            managedRuleGroupStatement: {
              name: "AWSManagedRulesCommonRuleSet",
              vendorName: "AWS",
            },
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "CRSRule",
            sampledRequestsEnabled: true,
          },
        },
        // rate limit rule
        {
          name: "RateLimitRule",
          priority: 1,
          statement: {
            rateBasedStatement: {
              aggregateKeyType: "IP",
              limit: 100,
              scopeDownStatement: {
                notStatement: {
                  statement: {
                    managedRuleGroupStatement: {
                      name: "AWSManagedRulesAmazonIpReputationList",
                      vendorName: "AWS",
                    },
                  },
                },
              },
            }
          },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "RateLimitRule",
            sampledRequestsEnabled: true,
          },
        },
      ],
    });

    this.waf_arn = webAcl.attrArn;
    this.waf_acl_id = webAcl.attrId;
  }
}
