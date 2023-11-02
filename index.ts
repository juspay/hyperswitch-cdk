import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { AWSStack } from "./lib/aws/stack";
import { Config } from "./lib/aws/config";

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

const config: Config = {
  stack: {
    name: "hyperswitch",
    region: "us-east-1",
  },
  vpc: {
    name: "hypers-vpc",
    availabilityZones: [process.env.CDK_DEFAULT_REGION+"a", process.env.CDK_DEFAULT_REGION+"b"],
    // subnetConfiguration: [],
  },
  subnet: {
    public: {
      name: "public",
    },
    dmz: {
      name: "private",
    },
  },
  extra_subnets: []
};

const allowedList: AccountRegion[] = require("./allowed.json");

const currentAccount: AccountRegion = {
  region: process.env.CDK_DEFAULT_REGION || undefined,
};

function assertAccountIsAllowed(current: AccountRegion, allowed: AccountRegion[]): void {
  const isAllowed = allowed.some(value => value.account === current.account && value.region === current.region);

  if (!isAllowed) {
    throw Error("The current account used by the CDK isn't allowed");
  }
}

if (!process.env.CDK_DEFAULT_REGION) {
  throw Error("please do `export CDK_DEFAULT_REGION=<your region>`");
}
console.log("current", currentAccount);
// assertAccountIsAllowed(currentAccount, allowedList);

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
