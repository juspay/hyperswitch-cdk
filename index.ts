import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { AWSStack } from "./lib/aws/stack";
import { Config } from "./lib/aws/config";
import { Configuration } from "./awsconfig";

const app = new cdk.App();

export enum Cloud {
  AWS = "AWS",
  GCP = "GCP",
  Azure = "Azure",
}

type AccountRegion = {
  account?: string;
  region?: string;
};

let config = new Configuration(app).getConfig();

const currentAccount: AccountRegion = {
  region: process.env.CDK_DEFAULT_REGION || undefined,
  account: process.env.CDK_DEFAULT_ACCOUNT || undefined,
};

if (!process.env.CDK_DEFAULT_REGION) {
  throw Error("please do `export CDK_DEFAULT_REGION=<your region>`");
}

console.log("current", currentAccount);

app.node.setContext("currentAccount", currentAccount);

class NewStack {
  private stack: Construct;

  constructor(scope: Construct, config: Config, cloudProvider: Cloud) {
    switch (cloudProvider) {
      case Cloud.AWS:
        this.stack = new AWSStack(scope, config);
        break;
      case Cloud.GCP:
        // this.stack = new GCPStack(scope, config);
        throw new Error("GCPStack is not implemented yet.");
      case Cloud.Azure:
        // this.stack = new AzureStack(scope, config);
        throw new Error("AzureStack is not implemented yet.");
      default:
        throw new Error(`Cloud provider ${cloudProvider} is not supported.`);
    }
  }

  getStack(): Construct {
    return this.stack;
  }
}

new NewStack(app, config, Cloud.AWS);
