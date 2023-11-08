import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Config } from "./aws/config";
import { AWSStack } from './aws/stack';
// import * as sqs from 'aws-cdk-lib/aws-sqs';

export enum Cloud {
  AWS = "AWS",
  GCP = "GCP",
  Azure = "Azure",
}
export class HyperswitchStack {

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
