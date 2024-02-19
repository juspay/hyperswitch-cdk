#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { Configuration } from "../awsconfig";
import { Cloud, HyperswitchStack } from "../lib/hs-stack";

const app = new cdk.App();
let config = new Configuration(app).getConfig();
type AccountRegion = {
  account?: string;
  region?: string;
};
const currentAccount: AccountRegion = {
  region: process.env.CDK_DEFAULT_REGION || undefined,
  account: process.env.CDK_DEFAULT_ACCOUNT || undefined,
};

if (!process.env.CDK_DEFAULT_REGION) {
  throw Error("please do `export CDK_DEFAULT_REGION=<your region>`");
}
app.node.setContext("currentAccount", currentAccount);
new HyperswitchStack(app, config, Cloud.AWS);

