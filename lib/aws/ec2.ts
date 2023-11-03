import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import * as cdk from "aws-cdk-lib";
import { readFileSync } from 'fs';
import { config } from 'process';
import { SubnetNames } from './networking';
export class EC2Instance {
    private readonly instance: ec2.Instance;
    sg: ec2.SecurityGroup;
    pubKey = "";
    privKey = "";
    err = "";

    constructor(scope: Construct , vpc: ec2.Vpc,  id: string, redis_host: string, db_host: string, password: string, admin_api_key: string, db_username: string, db_name: string) {

        const sg = new ec2.SecurityGroup(scope, 'Hyperswitch-ec2-SG', {
            securityGroupName: 'Hyperswitch-ec2-SG',
            vpc: vpc,
        });
        this.sg = sg;
        let keypair_id = "Hyperswitch-ec2-keypair"
        const awsKeyPair = new ec2.CfnKeyPair(scope, keypair_id, {
            keyName: "Hyperswitch-ec2-keypair",

        });

        let customData = readFileSync('lib/aws/userdata.sh', 'utf8').replace("{{redis_host}}", redis_host).replaceAll("{{db_host}}", db_host).replace("{{password}}", password).replace("{{admin_api_key}}", admin_api_key).replace("{{db_username}}", db_username).replace("{{db_name}}", db_name )   ;

        this.instance = new ec2.Instance(scope, id, {
            instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MEDIUM),
            machineImage: new ec2.AmazonLinuxImage(),
            vpc,
            vpcSubnets: { subnetGroupName: SubnetNames.PublicSubnet },
            securityGroup: sg,
            keyName: awsKeyPair.keyName,
            userData: ec2.UserData.custom(customData),
        });

        new cdk.CfnOutput(scope, 'Hyperswitch-ec2-IP', {
            value: "http://"+this.instance.instancePublicIp+"/health",
            description: 'try health api',
        });
    }

    public getInstance(): ec2.Instance {
        return this.instance;
    }
}
