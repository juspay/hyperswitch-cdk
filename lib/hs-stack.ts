import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { Config } from "./aws/config";
import { AWSStack } from "./aws/stack";
import { JusVault, StandaloneLockerConfig } from "../lib/aws/card-vault/stack";
// import * as sqs from 'aws-cdk-lib/aws-sqs';

export enum Cloud {
  AWS = "AWS",
  GCP = "GCP",
  Azure = "Azure",
}
export class HyperswitchStack {
  private stack: Construct;

  constructor(scope: Construct, config: Config, cloudProvider: Cloud) {
    const stack: string = scope.node.tryGetContext("stack") || "hyperswitch";
    console.log(stack);

    switch (stack) {
      case "hyperswitch":
        console.log("Deploying the Hyperswitch Stack!!");
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
            throw new Error(
              `Cloud provider ${cloudProvider} is not supported.`,
            );
        }
        break;
      case "card-vault":
        console.log("Deploying Locker Individually");
        const lockerConfig: StandaloneLockerConfig = {
          vpc_id: scope.node.getContext("vpc_id")!,
          name: scope.node.tryGetContext("stack_name") || "tartarus",
          master_key: scope.node.getContext("master_key"),
          db_user: scope.node.tryGetContext("db_user") || "locksmith",
          db_pass: scope.node.getContext("db_pass"),
        };

        this.stack = new JusVault(scope, lockerConfig);
        break;
    }
  }

  getStack(): Construct {
    return this.stack;
  }
}
