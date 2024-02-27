import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Config } from "./lib/aws/config";
import { Construct } from "constructs";

export class Configuration {
  config: Config;
  constructor(scope: Construct) {
    let db_pass = scope.node.tryGetContext('db_pass') || "dbpassword";
    let admin_api_key = scope.node.tryGetContext('admin_api_key') || "test_admin"
    let master_key = scope.node.tryGetContext('master_enc_key')
    let config: Config = {
      stack: {
        name: "hyperswitch",
        region: process.env.CDK_DEFAULT_REGION || "us-east-1"
      },
      vpc: {
        name: "hyperswitch-vpc",
        maxAzs: 2,
      },
      subnet: {
        public: {
          name: "public"
        },
        dmz: {
          name: "private"
        }
      },
      extra_subnets: [],
      rds: {
        port: 5432,
        db_user: "db_user",
        db_name: "hyperswitch",
        password: db_pass,
        writer_instance_class: ec2.InstanceClass.T3,
        writer_instance_size: ec2.InstanceSize.MEDIUM,
        reader_instance_class: ec2.InstanceClass.T3,
        reader_instance_size: ec2.InstanceSize.MEDIUM,
      },
      hyperswitch_ec2: {
        id: "hyperswitch",
        admin_api_key: admin_api_key,
        redis_host: "",
        db_host: "",
        master_enc_key: master_key
      },
      locker: {
        master_key: scope.node.tryGetContext('master_key'),
        db_user: "lockeruser",
        db_pass: scope.node.tryGetContext('locker_pass')

      },
      tags: {}
    }
    this.config = config;
  }
  getConfig() {
    return this.config;
  }
}
