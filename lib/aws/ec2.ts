import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';
import { EC2Config } from './config';
export class EC2Instance {
    private readonly instance: ec2.Instance;
    sg: ec2.SecurityGroup;

    constructor(scope: Construct , vpc: ec2.Vpc,  config: EC2Config ) {
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
        });

        // new cdk.CfnOutput(scope, '', {
        //     value: "http://"+this.instance.instancePublicIp+"/health",
        //     description: 'try health api',
        // });
    }

    public getInstance(): ec2.Instance {
        return this.instance;
    }
}
