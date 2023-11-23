// import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";

export enum Environment {
  Integ,
  Sandbox,
  Production,
}

export type StackConfig = {
  name: string;
  region: string;
  environment?: Environment;
};

/**
 * A simplified configuration for setting up VPC
 */
export type VpcConfig = {
  /**
   * Name of the VPC
   */
  name: string;
  /**
   * Availability Zones that the VPC should contain.
   * (eg. eu-central-1a)
   */
  availabilityZones: string[];
};

/**
 * A simplified configuration for setting up VPC
 */
export type SubnetConfigs = {
  public: SubnetConfig;
  dmz: SubnetConfig;
};

export type SubnetConfig = {
  name: string;
};

export type SSMConfig = {
  log_bucket_name: string;
};

export type ExtraSubnetConfig = {
  id: string;
  cidr: string;
};

export type RDSConfig = {
  port: number;
  password: string;
  db_user : string;
  db_name : string;
  writer_instance_class: ec2.InstanceClass;
  writer_instance_size: ec2.InstanceSize;
  reader_instance_class: ec2.InstanceClass;
  reader_instance_size: ec2.InstanceSize;
};

export type EC2 = {
  id: string;
  admin_api_key: string;
  redis_host: string;
  db_host : string;
};

export type Config = {
  stack: StackConfig;
  vpc: VpcConfig;
  subnet: SubnetConfigs;
  extra_subnets: ExtraSubnetConfig[]; // TODO: remove this if not required
  hyperswitch_ec2: EC2;
  rds: RDSConfig;
};

export type EC2Config = {
  id          : string;   // id of the instance
  machineImage: ec2.IMachineImage;
  instanceType: ec2.InstanceType;
  vpcSubnets  : ec2.SubnetSelection;
  securityGroup? : ec2.SecurityGroup;
  keyPair?  : ec2.CfnKeyPair;
  userData? : ec2.UserData;
}