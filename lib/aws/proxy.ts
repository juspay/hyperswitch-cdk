import { Construct } from "constructs";
import { Config } from "./config";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { AutoScalingGroup } from "aws-cdk-lib/aws-autoscaling";
import { readFileSync } from "fs";
import { ApplicationLoadBalancer } from "aws-cdk-lib/aws-elasticloadbalancingv2";

// ProxySetup is a construct that sets up a proxy server in the VPC
//
// The proxy server, comprises of 1 ASG and 1 LB, the ASG runs a ec2 instance template with envoy proxy installed, the envoy proxy should point to the host
// The load balancer should be internet facing and should be able to route traffic to the ASG instances
export class ProxySetup extends Construct {
  lb_sg: ec2.ISecurityGroup;
  asg_sg: ec2.ISecurityGroup;
  asg: AutoScalingGroup;
  lb: ApplicationLoadBalancer;
  constructor(
    scope: Construct,
    config: Config,
    vpc: ec2.Vpc,
    host: string,
    host_sg: ec2.ISecurityGroup,
  ) {
    super(scope, "ProxySetup");

    // read from envoy.sh 
    // infer the host as UPSTREAM_HOST
    const userData = ec2.UserData.custom(
      readFileSync("lib/aws/proxy/envoy.sh", "utf8") +
      "UPSTREAM_HOST=" + host + "\n" +
      "CLUSTER_NAME=" + "hyperswitch-cluster" + "\n" +
      "cat << EOF > /etc/envoy/envoy.yaml\n" +
      readFileSync("lib/aws/proxy/envoy.yaml", "utf8") +
      "EOF\n"
    );

    const asg_sg = new ec2.SecurityGroup(this, "ASGSG", {
      vpc,
    });

    const lb_sg = new ec2.SecurityGroup(this, "LBSG", {
      vpc,
    });

    // Create a ASG
    const asg = new AutoScalingGroup(this, "ASG", {
      vpc,
      instanceType: new ec2.InstanceType("t3.medium"),
      machineImage: new ec2.AmazonLinuxImage(),
      minCapacity: 1,
      maxCapacity: 3,
      desiredCapacity: 1,
      userData,
      securityGroup: asg_sg,
    });

    // Create a Load balancer
    const lb = new ApplicationLoadBalancer(this, "LB", {
      vpc,
      internetFacing: true,
      securityGroup: lb_sg,
    });

    // Add the ASG to the LB
    const listener = lb.addListener("Listener", {
      port: 80,
    });

    listener.addTargets("Target", {
      port: 80,
      targets: [asg],
    });
    
    lb_sg.addEgressRule(asg_sg, ec2.Port.tcp(80));
    asg_sg.addIngressRule(lb_sg, ec2.Port.tcp(80));

    lb_sg.addIngressRule(host_sg, ec2.Port.tcp(80));

    this.lb_sg = lb_sg;
    this.asg_sg = asg_sg;
    this.asg = asg;
    this.lb = lb;
  }
}
