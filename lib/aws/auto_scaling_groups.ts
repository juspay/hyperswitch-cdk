import { AutoScalingGroup, HealthCheck } from "aws-cdk-lib/aws-autoscaling";
import {
  ILaunchTemplate,
  IMachineImage,
  ISecurityGroup,
  IVpc,
  InstanceType,
  Port,
  SecurityGroup,
  SubnetSelection,
} from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";

export class ApplicationAutoScalingGroup {
  asgInner: AutoScalingGroup;
  securityGroup: ISecurityGroup;
  constructor(
    scope: Construct,
    id: string,
    resources: {
      vpc: IVpc;
      subnet?: SubnetSelection;
      instanceType: InstanceType;
      machineImage: IMachineImage;
      scale: {
        min: number;
        max: number;
        desired: number;
      };
      customHealthCheck?: HealthCheck;
      launchTemplate: ILaunchTemplate;
    },
    sgCfg: {
      name: string;
      description: string;
    },
  ) {
    const sg = new SecurityGroup(scope, sgCfg.name, {
      vpc: resources.vpc,
      description: sgCfg.description,
      allowAllOutbound: false,
    });

    this.securityGroup = sg;

    const applicationASG = new AutoScalingGroup(scope, id, {
      vpc: resources.vpc,
      vpcSubnets: resources.subnet,
      instanceType: resources.instanceType,
      machineImage: resources.machineImage,
      allowAllOutbound: false,
      maxCapacity: resources.scale.max,
      minCapacity: resources.scale.min,
      desiredCapacity: resources.scale.desired,
      // TODO: Provide spot price
      healthCheck: resources.customHealthCheck || HealthCheck.ec2(),
      launchTemplate: resources.launchTemplate,
      securityGroup: sg,
    });

    this.asgInner = applicationASG;
  }

  addClient(
    peer: ISecurityGroup,
    port: number,
    description?: {
      ingressDesc: string;
      egressDesc: string;
    },
  ) {
    this.securityGroup.addIngressRule(
      peer,
      Port.tcp(port),
      description?.ingressDesc,
    );
    peer.addEgressRule(
      this.securityGroup,
      Port.tcp(port),
      description?.egressDesc,
    );
  }
}
