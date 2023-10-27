import { Construct } from "constructs";
import { ApplicationAutoScalingGroup } from "../auto_scaling_groups";
import { LoadBalancer } from "./load_balancers";
import {
  IVpc,
  InstanceClass,
  InstanceSize,
  InstanceType,
  LaunchTemplate,
  MachineImage,
  SubnetSelection,
  UserData,
} from "aws-cdk-lib/aws-ec2";
import { Repository } from "aws-cdk-lib/aws-ecr";
import { EcrImage } from "aws-cdk-lib/aws-ecs";
import { HealthCheck } from "aws-cdk-lib/aws-autoscaling";

type LoadBalancedAutoScaler = {
  loadBalancer: LoadBalancer;
  asg: ApplicationAutoScalingGroup;
};

export function envoyBuilder(
  scope: Construct,
  configuration: {
    user_data: string;
  },
  resources: {
    vpc: IVpc;
    subnet: SubnetSelection;
  },
  image: {
    ami_name: string;
  },
) {
  const instanceType = InstanceType.of(InstanceClass.T4G, InstanceSize.MEDIUM);
  const machineImage = MachineImage.lookup({
    name: image.ami_name,
  });

  const launchTemplate = new LaunchTemplate(scope, "envoy-lt", {
    instanceType,
    machineImage,
    userData: UserData.forLinux({
      shebang: configuration.user_data,
    }),
  });

  const asg = new ApplicationAutoScalingGroup(
    scope,
    "envoy-inbound-proxy-asg",
    {
      vpc: resources.vpc,
      subnet: resources.subnet,
      instanceType: instanceType,
      machineImage: machineImage,
      scale: {
        min: 2,
        max: 10,
        desired: 3,
      },
      launchTemplate,
    },
    {
      name: "envoy-asg-sg",
      description: "security group connected to envoy asg",
    },
  );

  const loadBalancer = new LoadBalancer(
    scope,
    "api-public",
    {
      vpc: resources.vpc,
      vpcSubnet: resources.subnet,
      internet_facing: true,
      asg: asg.asgInner,
    },
    {
      name: "api-public-sg",
      description: "security group for api-public load balancer",
    },
  );

  asg.addClient(loadBalancer.securityGroup, 80);

  loadBalancer.addListener("HTTP", 80, {
    name: "envoy-asg-tg",
    port: 80,
    target: asg.asgInner,
  });
}



export function squidBuilder(
  scope: Construct,
  configuration: {
    user_data: string;
  },
  resources: {
    vpc: IVpc;
    subnet: SubnetSelection;
  },
  image: {
    ami_name: string;
  },
) {
  const instanceType = InstanceType.of(InstanceClass.T4G, InstanceSize.MEDIUM);
  const machineImage = MachineImage.lookup({
    name: image.ami_name,
  });

  const launchTemplate = new LaunchTemplate(scope, "squid-lt", {
    instanceType,
    machineImage,
    userData: UserData.forLinux({
      shebang: configuration.user_data,
    }),
  });

  const asg = new ApplicationAutoScalingGroup(
    scope,
    "squid-outbound-proxy-asg",
    {
      vpc: resources.vpc,
      subnet: resources.subnet,
      instanceType: instanceType,
      machineImage: machineImage,
      scale: {
        min: 2,
        max: 10,
        desired: 3,
      },
      launchTemplate,
    },
    {
      name: "squid-asg-sg",
      description: "security group connected to envoy asg",
    },
  );

  const loadBalancer = new LoadBalancer(
    scope,
    "squid-alb",
    {
      vpc: resources.vpc,
      vpcSubnet: resources.subnet,
      internet_facing: true,
      asg: asg.asgInner,
    },
    {
      name: "squid-lb-sg",
      description: "security group for api-public load balancer",
    },
  );

  asg.addClient(loadBalancer.securityGroup, 80);

  loadBalancer.addListener("HTTP", 80, {
    name: "squid-asg-tg",
    port: 80,
    target: asg.asgInner,
  });

  loadBalancer.addListener("HTTP", 443, {
    name: "squid-asg-tg",
    port: 443,
    target: asg.asgInner,
  });
}
