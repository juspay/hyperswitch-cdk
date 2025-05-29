import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';
import { EC2Config } from './config';
import * as cdk from "aws-cdk-lib";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";

export class EC2Instance implements elbv2.IApplicationLoadBalancerTarget {
    private readonly instance: ec2.Instance;
    sg: ec2.SecurityGroup;

    constructor(scope: Construct , vpc: ec2.Vpc,  config: EC2Config, executeAfter?: ec2.Instance ) {
        let id = config.id;
        let sg;
        let keyName;

        if (config.securityGroup){
            sg = config.securityGroup;
        }else {
            let sg_id = id+'-SG';
            sg = new ec2.SecurityGroup(scope, sg_id, {
                securityGroupName: sg_id,
                vpc: vpc,
                allowAllOutbound: config.allowOutboundTraffic,
            });
        }
        this.sg = sg;

        if(config.keyPair){
            keyName = config.keyPair.keyName;
        }else{
            let keypair_id = id+'-keypair';
            let awsKeyPair = new ec2.CfnKeyPair(scope, keypair_id, {
                keyName: keypair_id,
              });
            keyName = awsKeyPair.keyName;
        }

        this.instance = new ec2.Instance(scope, id, {
            vpc,
            keyName: keyName,
            securityGroup: sg,
            userData: config.userData,
            vpcSubnets: config.vpcSubnets,
            instanceType: config.instanceType,
            machineImage: config.machineImage,
            ssmSessionPermissions: config.ssmSessionPermissions,
            associatePublicIpAddress: config.associatePublicIpAddress,
            role: config.role
        });

        if (executeAfter){
            this.instance.node.addDependency(executeAfter);
        }
    }

    public getInstance(): ec2.Instance {
        return this.instance;
    }

    addClient(sg: ec2.ISecurityGroup, port: ec2.Port) {
        sg.addEgressRule(this.sg, port);
        this.sg.addIngressRule(sg, port);
    }

    attachToApplicationTargetGroup(targetGroup: elbv2.IApplicationTargetGroup): elbv2.LoadBalancerTargetProps {
        return {
            targetType: elbv2.TargetType.INSTANCE,
            targetJson: { id: this.instance.instanceId }
        };
    }
}
