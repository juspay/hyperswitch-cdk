import { AutoScalingGroup } from "aws-cdk-lib/aws-autoscaling";
import {
  ISecurityGroup,
  IVpc,
  SecurityGroup,
  SubnetSelection,
} from "aws-cdk-lib/aws-ec2";
import {
  ApplicationListener,
  ApplicationLoadBalancer,
  HealthCheck,
  IApplicationLoadBalancerTarget,
} from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { Construct } from "constructs";

export class LoadBalancer {
  loadBalancer: ApplicationLoadBalancer;
  securityGroup: ISecurityGroup;
  listeners: ApplicationListener[];
  constructor(
    scope: Construct,
    name: string,
    resources: {
      vpc: IVpc;
      asg: AutoScalingGroup;
      internet_facing: boolean;
      vpcSubnet?: SubnetSelection;
    },
    sgCfg: { name: string; description: string },
  ) {
    const lbSg = new SecurityGroup(scope, sgCfg.name, {
      vpc: resources.vpc,
      description: sgCfg.description,
      allowAllOutbound: false,
    });

    this.securityGroup = lbSg;

    this.loadBalancer = new ApplicationLoadBalancer(scope, name, {
      vpc: resources.vpc,
      vpcSubnets: resources.vpcSubnet,
      internetFacing: resources.internet_facing,
      securityGroup: lbSg,
    });

    this.listeners = [];
  }

  addListener(
    id: string,
    port: number,
    target: {
      name: string;
      port: number;
      target: IApplicationLoadBalancerTarget;
    },
  ) {
    const listener = this.loadBalancer.addListener(id, {
      port,
      open: true,
    });
    this.listeners.push(listener);

    listener.addTargets(target.name, {
      port: target.port,
      targets: [target.target],
    });
  }
}
